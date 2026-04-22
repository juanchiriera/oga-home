import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2/options";
import * as logger from "firebase-functions/logger";

if (!admin.apps.length) {
  admin.initializeApp();
}

setGlobalOptions({ region: "southamerica-east1" });

export const health = onRequest((req, res) => {
  logger.info("health check");
  res.status(200).send("ok");
});

export {
  acceptFamilyInvite,
  createFamily,
  createFamilyInvite,
  revokeFamilyInvite,
} from "./callables/familyCallables.js";
