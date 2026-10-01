import {defineSecret, defineString} from "firebase-functions/params";

export const geminiApiKey = defineSecret("GEMINI_API_KEY");

export const geminiModel = defineString("GEMINI_MODEL", {
  default: "gemini-3.5-flash",
});

export const allowedOrigins = defineString("ALLOWED_ORIGINS", {
  default:
    "http://localhost:4174,http://127.0.0.1:4174," +
    "http://localhost:4190,http://127.0.0.1:4190," +
    "https://dardito-742d2.web.app,https://dardito-742d2.firebaseapp.com," +
    "https://chocolate-chimpanzee-899948.hostingersite.com," +
    "https://darditohistoriasplatenses.com,https://www.darditohistoriasplatenses.com",
});

export const region = "southamerica-east1";
