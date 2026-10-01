import {defineSecret, defineString} from "firebase-functions/params";

// WhatsApp is isolated so web-only deployments never require Meta secrets.
export const whatsappAccessToken = defineSecret("WHATSAPP_ACCESS_TOKEN");
export const whatsappVerifyToken = defineSecret("WHATSAPP_VERIFY_TOKEN");
export const whatsappPhoneNumberId = defineSecret("WHATSAPP_PHONE_NUMBER_ID");
export const whatsappAppSecret = defineSecret("WHATSAPP_APP_SECRET");

export const whatsappGraphVersion = defineString("WHATSAPP_GRAPH_VERSION", {
  default: "v25.0",
});
