import {execFile} from "node:child_process";
import {readFile} from "node:fs/promises";
import {fileURLToPath} from "node:url";
import {promisify} from "node:util";
import {cert, getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

import type {CorpusItem} from "../domain/types.js";

const path = fileURLToPath(new URL("../../seed/corpus.json", import.meta.url));
const corpus = JSON.parse(await readFile(path, "utf8")) as CorpusItem[];
const credentialPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

function metadata(item: CorpusItem) {
  if (
    !item.subtitle || !Number.isFinite(item.latitude) ||
    !Number.isFinite(item.longitude) || !item.readingMinutes
  ) {
    throw new Error(`Faltan metadatos públicos para ${item.id}.`);
  }
  return {
    subtitle: item.subtitle,
    latitude: item.latitude as number,
    longitude: item.longitude as number,
    featured: item.featured === true,
    readingMinutes: item.readingMinutes,
  };
}

if (credentialPath) {
  if (getApps().length === 0) initializeApp({credential: cert(credentialPath)});
  const db = getFirestore();
  const batch = db.batch();
  for (const item of corpus) {
    batch.set(db.collection("knowledge").doc(item.id), metadata(item), {merge: true});
  }
  await batch.commit();
} else {
  const {stdout} = await promisify(execFile)("gcloud", ["auth", "print-access-token"]);
  const accessToken = stdout.trim();
  if (!accessToken) throw new Error("gcloud no devolvió un token de acceso.");
  const projectId = process.env.GCLOUD_PROJECT ??
    process.env.GOOGLE_CLOUD_PROJECT ?? "dardito-742d2";
  const masks = ["subtitle", "latitude", "longitude", "featured", "readingMinutes"]
    .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
    .join("&");
  for (const item of corpus) {
    const values = metadata(item);
    const response = await fetch(
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/` +
        `documents/knowledge/${encodeURIComponent(item.id)}?${masks}`,
      {
        method: "PATCH",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          fields: {
            subtitle: {stringValue: values.subtitle},
            latitude: {doubleValue: values.latitude},
            longitude: {doubleValue: values.longitude},
            featured: {booleanValue: values.featured},
            readingMinutes: {integerValue: String(values.readingMinutes)},
          },
        }),
      },
    );
    if (!response.ok) {
      throw new Error(`No se pudo migrar ${item.id} (${response.status}): ${await response.text()}`);
    }
  }
}

console.log(`Metadatos públicos migrados sin reemplazar contenido editorial: ${corpus.length}.`);
