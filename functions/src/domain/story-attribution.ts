import {HttpsError} from "firebase-functions/v2/https";

export type AuthorDisplay = "user" | "email" | "name";
export function resolveAttribution(
  input: Record<string, unknown>, current: Record<string, unknown>,
  submission: Record<string, unknown> | undefined, role: string,
): {authorDisplay: AuthorDisplay; publicAuthor: string} {
  const linked = typeof current.sourceSubmissionId === "string" && current.sourceSubmissionId.trim();
  if (!linked) return {authorDisplay: "user", publicAuthor: ""};
  const mode = input.authorDisplay ?? current.authorDisplay ?? "user";
  if (!["user", "email", "name"].includes(String(mode))) throw new HttpsError("invalid-argument", "Seleccioná cómo mostrar al autor.");
  const name = input.authorName ?? current.publicAuthor;
  if (role !== "admin") {
    if (mode !== (current.authorDisplay ?? "user") || (mode === "name" && name !== current.publicAuthor)) {
      throw new HttpsError("permission-denied", "Solo un admin puede cambiar la identidad pública.");
    }
    return {authorDisplay: (current.authorDisplay as AuthorDisplay) ?? "user", publicAuthor: typeof current.publicAuthor === "string" ? current.publicAuthor : "Un usuario"};
  }
  if (mode === "user") return {authorDisplay: "user", publicAuthor: "Un usuario"};
  if (!submission || typeof submission.userId !== "string" || !submission.userId) throw new HttpsError("failed-precondition", "No se pudo verificar el aporte original.");
  if (mode === "email") {
    const email = submission.email;
    if (typeof email !== "string" || email.length > 254 || !/^[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+$/.test(email)) throw new HttpsError("failed-precondition", "El aporte no tiene un correo válido.");
    return {authorDisplay: "email", publicAuthor: email};
  }
  if (typeof name !== "string" || !name.trim() || name.trim().length > 100 || /[<>\u0000-\u001f\u007f]/.test(name)) throw new HttpsError("invalid-argument", "Ingresá un nombre válido de hasta 100 caracteres.");
  return {authorDisplay: "name", publicAuthor: name.trim()};
}

export function publicAttribution(raw: Record<string, unknown>): string | null {
  if (typeof raw.sourceSubmissionId !== "string" || !raw.sourceSubmissionId.trim()) return null;
  if (raw.authorDisplay !== "name" && raw.authorDisplay !== "email") return "Un usuario";
  const value = raw.publicAuthor;
  if (typeof value !== "string" || !value.trim() || value.length > (raw.authorDisplay === "email" ? 254 : 100) || /[<>\u0000-\u001f\u007f]/.test(value)) return "Un usuario";
  return value;
}
