import {setGlobalOptions} from "firebase-functions/v2";

import {region} from "./config.js";

setGlobalOptions({region, maxInstances: 20});

export {
  darditoChat,
  health,
  submitStory,
  upsertKnowledge,
  upsertUserProfile,
} from "./channels/http.js";
export {verifyMppAccess} from "./channels/mpp.js";

// WhatsApp remains implemented but is intentionally not exported until the
// Meta credentials are configured.
