import {getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";

import {
  defaultDarditoParameters,
  normalizeDarditoParameters,
  type DarditoParameters,
} from "../domain/dardito-parameters.js";

const collection = "editorial_config";
const documentId = "dardito_parameters";
const cacheMilliseconds = 10_000;

let cached: {value: DarditoParameters; expiresAt: number} | null = null;

export async function loadDarditoParameters(): Promise<DarditoParameters> {
  if (cached && cached.expiresAt > Date.now()) return cached.value;
  try {
    const snapshot = await getFirestore().collection(collection).doc(documentId).get();
    const value = snapshot.exists
      ? normalizeDarditoParameters(snapshot.data())
      : defaultDarditoParameters;
    cached = {value, expiresAt: Date.now() + cacheMilliseconds};
    return value;
  } catch (error) {
    logger.error("No se pudo leer la configuración de Dardito; se usan valores seguros por defecto.", error);
    cached = {value: defaultDarditoParameters, expiresAt: Date.now() + cacheMilliseconds};
    return defaultDarditoParameters;
  }
}

export function invalidateDarditoParametersCache(): void {
  cached = null;
}

export const darditoParametersReference = () => getFirestore().collection(collection).doc(documentId);
