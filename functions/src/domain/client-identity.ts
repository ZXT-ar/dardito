import {isIP} from "node:net";

/**
 * Cloud Run / Cloud Functions append the transport client's address to XFF.
 * Verified on both deployed direct URLs: earlier entries remain client-controlled.
 * Do not use Express request.ip here: Functions Framework trusts every proxy.
 */
export function trustedClientIdentity(request: {
  headers: Record<string, string | string[] | undefined>;
  socket?: {remoteAddress?: string};
}): string {
  const header = request.headers["x-forwarded-for"];
  const value = Array.isArray(header) ? header.at(-1) : header;
  const appendedAddress = value?.slice(value.lastIndexOf(",") + 1).trim();
  if (appendedAddress && isIP(appendedAddress)) return appendedAddress.toLowerCase();
  const peer = request.socket?.remoteAddress;
  if (peer && isIP(peer)) return peer.toLowerCase();
  // A malformed/absent trusted address shares a fail-closed bucket. Never fall
  // back to another forwarded entry or a caller-controlled header.
  return "unresolved-transport";
}
