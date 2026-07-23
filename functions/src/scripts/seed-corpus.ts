import {execFile} from "node:child_process";
import {readFile} from "node:fs/promises";
import {fileURLToPath} from "node:url";
import {promisify} from "node:util";
import {cert, getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

import type {CorpusItem} from "../domain/types.js";

const path = fileURLToPath(new URL("../../seed/corpus.json", import.meta.url));
const corpus = JSON.parse(await readFile(path, "utf8")) as CorpusItem[];
const credentialPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (credentialPath) {
  if (getApps().length === 0) {
    initializeApp({credential: cert(credentialPath)});
  }
  const db = getFirestore();
  const batch = db.batch();
  for (const item of corpus) {
    batch.set(db.collection("knowledge").doc(item.id), {
      ...item,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  await batch.commit();
} else {
  const {stdout} = await promisify(execFile)("gcloud", ["auth", "print-access-token"]);
  const accessToken = stdout.trim();
  if (!accessToken) throw new Error("gcloud no devolvió un token de acceso.");

  const projectId =
    process.env.GCLOUD_PROJECT ??
    process.env.GOOGLE_CLOUD_PROJECT ??
    "dardito-742d2";
  const timestamp = new Date().toISOString();
  const writes = corpus.map((item) => ({
    update: {
      name:
        `projects/${projectId}/databases/(default)/documents/knowledge/` +
        encodeURIComponent(item.id),
      fields: {
        id: {stringValue: item.id},
        title: {stringValue: item.title},
        summary: {stringValue: item.summary},
        body: {stringValue: item.body},
        category: {stringValue: item.category},
        neighborhood: {stringValue: item.neighborhood},
        period: {stringValue: item.period ?? ""},
        evidence: {stringValue: item.evidence},
        sourceName: {stringValue: item.sourceName ?? ""},
        keywords: {
          arrayValue: {
            values: item.keywords.map((keyword) => ({stringValue: keyword})),
          },
        },
        status: {stringValue: item.status},
        updatedAt: {timestampValue: timestamp},
      },
    },
  }));

  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/` +
      "databases/(default)/documents:batchWrite",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({writes}),
    },
  );
  if (!response.ok) {
    throw new Error(`Firestore REST rechazó el corpus (${response.status}): ${await response.text()}`);
  }
}

console.log(`Corpus cargado: ${corpus.length} historias.`);
