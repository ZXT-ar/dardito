// Reply only to user content, never to reactions, system notices or delivery receipts.
const unsupportedUserContent = new Set([
  "audio", "image", "video", "sticker", "document", "location", "contacts",
  "interactive", "button", "order", "unknown", "unsupported",
]);

export function needsWhatsAppFormatNotice(type: string | undefined): boolean {
  return typeof type === "string" && unsupportedUserContent.has(type);
}

export const whatsappFormatNotice = "Solo puedo responder consultas escritas sobre las historias de La Plata. " +
  "No puedo revisar ni verificar el contenido de ese formato. " +
  "Si querés hacer una consulta, escribila en texto, sin incluir datos personales.";
