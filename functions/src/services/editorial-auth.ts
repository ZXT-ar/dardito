import {getAuth, type UserRecord} from "firebase-admin/auth";
import {HttpsError} from "firebase-functions/v2/https";

import {isActiveEditorialSession, roleOf, type EditorialRole} from "../domain/editorial-auth.js";

export interface EditorialRequest {
  auth?: {uid: string; token: Record<string, unknown>};
}

export async function requireCurrentEditorialUser(request: EditorialRequest): Promise<UserRecord> {
  if (!request.auth) throw new HttpsError("unauthenticated", "Necesitás iniciar sesión.");
  const user = await getAuth().getUser(request.auth.uid);
  if (!isActiveEditorialSession(user, request.auth.token)) {
    throw new HttpsError("unauthenticated", "La sesión editorial ya no está habilitada. Volvé a iniciar sesión.");
  }
  return user;
}

export async function requireEditorialRole(request: EditorialRequest, allowed: EditorialRole[]) {
  const user = await requireCurrentEditorialUser(request);
  const role = roleOf(user.customClaims ?? {});
  if (!role || !allowed.includes(role)) {
    throw new HttpsError("permission-denied", "Tu rol no permite realizar esta acción.");
  }
  return {uid: user.uid, role, email: user.email ?? ""};
}
