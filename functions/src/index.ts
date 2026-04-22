import { setGlobalOptions } from "firebase-functions/v2/options";
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

setGlobalOptions({ region: "southamerica-east1" });

export const health = onRequest((req, res) => {
  logger.info("health check");
  res.status(200).send("ok");
});
