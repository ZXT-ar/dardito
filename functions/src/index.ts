import {setGlobalOptions} from "firebase-functions/v2";

import {region} from "./config.js";

setGlobalOptions({region, maxInstances: 20});

export {darditoChat, health, submitStory, upsertKnowledge} from "./channels/http.js";

// WhatsApp remains implemented but is intentionally not exported until the
// Meta credentials are configured.
