import * as admin from "firebase-admin";
import { createHmac, timingSafeEqual } from "node:crypto";
import type { Request, Response } from "express";
import * as logger from "firebase-functions/logger";
import { defineSecret, defineString } from "firebase-functions/params";

export const rcWebhookSecret = defineSecret("RC_WEBHOOK_SECRET");
const rcWebhookSignatureHeader = defineString("RC_WEBHOOK_SIGNATURE_HEADER", {
  default: "X-RevenueCat-Signature",
});

type RevenueCatEvent = {
  id?: string;
  event_timestamp_ms?: number;
  app_user_id?: string;
  type?: string;
  product_id?: string;
  entitlement_ids?: string[];
  environment?: string;
  expiration_at_ms?: number | null;
};

type RevenueCatWebhookBody = {
  api_version?: string;
  event?: RevenueCatEvent;
};

type BillingStatus =
  | "unknown"
  | "free"
  | "active"
  | "grace"
  | "expired"
  | "billing_issue";

type RequestWithRawBody = Request & { rawBody?: Buffer };

function getRequiredHeader(req: Request): string | null {
  const configuredHeader = rcWebhookSignatureHeader.value().trim();
  const configuredValue = req.get(configuredHeader);
  if (configuredValue) {
    return configuredValue;
  }
  if (configuredHeader.toLowerCase() !== "x-revenuecat-signature") {
    return req.get("X-RevenueCat-Signature") ?? null;
  }
  return null;
}

function computeRevenueCatSignature(rawBody: Buffer, secret: string): string {
  return createHmac("sha256", secret).update(rawBody).digest("hex");
}

function isSignatureValid(
  providedSignature: string,
  rawBody: Buffer,
  secret: string,
): boolean {
  const normalizedProvided = providedSignature.trim().toLowerCase();
  const expectedSignature = computeRevenueCatSignature(rawBody, secret);
  const providedBuffer = Buffer.from(normalizedProvided, "utf8");
  const expectedBuffer = Buffer.from(expectedSignature, "utf8");
  if (providedBuffer.length !== expectedBuffer.length) {
    return false;
  }
  return timingSafeEqual(providedBuffer, expectedBuffer);
}

function mapBillingStatus(type: string): BillingStatus {
  switch (type) {
  case "INITIAL_PURCHASE":
  case "RENEWAL":
  case "UNCANCELLATION":
  case "PRODUCT_CHANGE":
    return "active";
  case "BILLING_ISSUE":
    return "billing_issue";
  case "CANCELLATION":
    return "grace";
  case "EXPIRATION":
    return "expired";
  case "TRANSFER":
    return "active";
  default:
    return "unknown";
  }
}

/** Alineado con assertEntitlement en familyCallables (billing/entitlements). */
function invitesEntitlementEnabled(status: BillingStatus): boolean {
  switch (status) {
  case "active":
  case "grace":
  case "billing_issue":
    return true;
  case "expired":
  case "free":
  case "unknown":
  default:
    return false;
  }
}

function normalizeEntitlements(event: RevenueCatEvent): string[] {
  const entitlements = event.entitlement_ids ?? [];
  return entitlements.filter((value) => value.trim().length > 0);
}

function hasNoAdsEntitlement(entitlements: string[]): boolean {
  return entitlements.includes("no_ads") || entitlements.includes("no-ads");
}

function isAlreadyExistsError(error: unknown): boolean {
  const maybeCode = (error as { code?: number | string }).code;
  return maybeCode === 6 || maybeCode === "already-exists";
}

function readEvent(req: Request): RevenueCatEvent {
  const body = req.body as RevenueCatWebhookBody | undefined;
  return body?.event ?? {};
}

export async function revenueCatWebhook(
  req: RequestWithRawBody,
  res: Response,
): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ ok: false, error: "method_not_allowed" });
    return;
  }

  const signature = getRequiredHeader(req);
  if (!signature) {
    res.status(401).json({ ok: false, error: "missing_signature" });
    return;
  }

  const secret = rcWebhookSecret.value();
  const rawBody: Buffer = req.rawBody ?? Buffer.from(JSON.stringify(req.body));
  if (!isSignatureValid(signature, rawBody, secret)) {
    logger.warn("revenuecatWebhook.invalidSignature");
    res.status(401).json({ ok: false, error: "invalid_signature" });
    return;
  }

  const event = readEvent(req);
  const eventId = String(event.id ?? "").trim();
  const familyId = String(event.app_user_id ?? "").trim();
  const eventType = String(event.type ?? "").trim();

  if (!eventId || !familyId || !eventType) {
    res.status(400).json({ ok: false, error: "invalid_event_payload" });
    return;
  }

  const db = admin.firestore();
  const eventRef = db
    .collection("families")
    .doc(familyId)
    .collection("billingEvents")
    .doc(eventId);

  try {
    await eventRef.create({
      eventId,
      familyId,
      type: eventType,
      productId: event.product_id ?? null,
      entitlements: normalizeEntitlements(event),
      environment: event.environment ?? null,
      eventTimestampMs: event.event_timestamp_ms ?? null,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: req.body,
    });
  } catch (error) {
    if (isAlreadyExistsError(error)) {
      res.status(200).json({ ok: true, duplicate: true, eventId });
      return;
    }
    throw error;
  }

  const now = Date.now();
  const billingStatus = mapBillingStatus(eventType);
  const entitlements = normalizeEntitlements(event);
  const billingCurrentRef = db
    .collection("families")
    .doc(familyId)
    .collection("billing")
    .doc("current");

  await billingCurrentRef.set(
    {
      familyId,
      source: "revenuecat",
      status: billingStatus,
      productId: event.product_id ?? null,
      entitlements,
      environment: event.environment ?? null,
      lastEventId: eventId,
      lastEventType: eventType,
      lastEventTimestampMs: event.event_timestamp_ms ?? now,
      expirationAtMs: event.expiration_at_ms ?? null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const billingEntitlementsRef = db
    .collection("families")
    .doc(familyId)
    .collection("billing")
    .doc("entitlements");

  await billingEntitlementsRef.set(
    {
      familyId,
      source: "revenuecat",
      entitlements: {
        invites: invitesEntitlementEnabled(billingStatus),
        no_ads: hasNoAdsEntitlement(entitlements),
      },
      lastEventId: eventId,
      lastEventType: eventType,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  logger.info("revenuecatWebhook.processed", {
    familyId,
    eventId,
    eventType,
    status: billingStatus,
  });
  res.status(200).json({ ok: true, duplicate: false, eventId });
}

export const __internal = {
  computeRevenueCatSignature,
  isSignatureValid,
  mapBillingStatus,
  invitesEntitlementEnabled,
  hasNoAdsEntitlement,
  isAlreadyExistsError,
};
