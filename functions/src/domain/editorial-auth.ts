export type EditorialRole = "reviewer" | "editor" | "admin";

export function roleOf(claims: Record<string, unknown>): EditorialRole | null {
  if (claims.admin === true || claims.role === "admin") return "admin";
  if (claims.editor === true || claims.role === "editor") return "editor";
  if (claims.reviewer === true || claims.role === "reviewer") return "reviewer";
  return null;
}

export function isActiveEditorialSession(
  user: {disabled: boolean; email?: string; emailVerified: boolean; tokensValidAfterTime?: string},
  token: Record<string, unknown>,
): boolean {
  if (user.disabled || !user.email || !user.emailVerified) return false;
  const authenticatedAt = token.auth_time;
  if (typeof authenticatedAt !== "number" || !Number.isSafeInteger(authenticatedAt) || authenticatedAt <= 0) {
    return false;
  }
  if (!user.tokensValidAfterTime) return true;
  const validAfter = Date.parse(user.tokensValidAfterTime);
  return Number.isFinite(validAfter) && authenticatedAt * 1_000 >= validAfter;
}
