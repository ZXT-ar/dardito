export const maxMessageLength = 350;
const characters = new Intl.Segmenter("es", {granularity: "grapheme"});

export function sanitizeMessage(message: string): string {
  if (typeof message !== "string") throw new Error("INVALID_MESSAGE");
  let count = 0;
  for (const _ of characters.segment(message)) {
    if (++count > maxMessageLength) throw new Error("INVALID_MESSAGE");
  }
  const value = message.replace(/[\u0000-\u001F\u007F]/g, " ").trim();
  if (!value) throw new Error("INVALID_MESSAGE");
  return value;
}
