import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {region} from "../config.js";
import {enforceRateLimit, privacyHash} from "../services/rate-limit.js";

if (getApps().length === 0) initializeApp();

const sessionDurationMilliseconds = 14 * 60_000 + 30_000;
const allowedMppOrigins = [
  "https://mpp-simbiosisdigital-dardito.web.app",
  "http://localhost:4174",
  "http://127.0.0.1:4174",
];

const dashboard = {
  project: {
    name: "Dardito",
    description:
      "Historias, misterios y cultura inteligente para la ciudad de La Plata.",
    startedAt: "Julio 2026",
    mode: "Desarrollo activo",
    updatedAt: "24 jul 2026",
  },
  areas: [
    {
      id: "design",
      short: "01",
      label: "Diseño y experiencia",
      description:
        "Identidad, sistema visual y experiencia responsive de todo el producto.",
      progress: 92,
      tone: "violet",
      tasks: [
        {
          title: "Identidad visual de Dardito",
          detail: "Personaje, paleta, tono editorial y lenguaje de marca.",
          status: "done",
        },
        {
          title: "Sistema de diseño responsive",
          detail: "Componentes, navegación, tipografías y estados interactivos.",
          status: "done",
        },
        {
          title: "Flujos principales",
          detail: "Inicio, mapa, chat, contribuciones, PWA y legales.",
          status: "done",
        },
        {
          title: "Accesibilidad y consistencia final",
          detail: "Auditoría de contraste, foco, lectores y microcopy.",
          status: "review",
        },
      ],
    },
    {
      id: "web",
      short: "02",
      label: "App web",
      description:
        "Aplicación Flutter, datos, mapa, inteligencia artificial e infraestructura.",
      progress: 84,
      tone: "cyan",
      tasks: [
        {
          title: "Aplicación web y PWA",
          detail: "Experiencia responsive instalable en mobile y desktop.",
          status: "done",
        },
        {
          title: "Mapa de historias",
          detail: "Google Maps, filtros, marcadores y fichas contextuales.",
          status: "done",
        },
        {
          title: "Dardito conversacional",
          detail: "LLM, corpus, moderación, rate limiting y memoria de sesión.",
          status: "done",
        },
        {
          title: "Autenticación y aportes",
          detail: "Ingreso con Google, imágenes y recepción segura de historias.",
          status: "done",
        },
        {
          title: "Panel editorial y métricas",
          detail: "Moderación operativa, analítica y administración de contenidos.",
          status: "pending",
        },
        {
          title: "QA integral de producción",
          detail: "Pruebas finales por navegador, dispositivo y recuperación.",
          status: "review",
        },
      ],
    },
    {
      id: "whatsapp",
      short: "03",
      label: "Dardito en WhatsApp",
      description:
        "Canal conversacional conectado a la misma inteligencia y contenidos.",
      progress: 38,
      tone: "lime",
      tasks: [
        {
          title: "Arquitectura multicanal",
          detail: "Servicio compartido entre la app web y futuros canales.",
          status: "done",
        },
        {
          title: "Webhook y adaptador base",
          detail: "Recepción, normalización y respuesta de mensajes.",
          status: "review",
        },
        {
          title: "Alta de Meta Business",
          detail: "Cuenta, número, aplicación y validación comercial.",
          status: "pending",
        },
        {
          title: "Secretos y plantillas",
          detail: "Tokens permanentes, verificación y mensajes aprobados.",
          status: "pending",
        },
        {
          title: "Pruebas de conversación",
          detail: "Mensajes reales, reintentos, límites y derivación a la web.",
          status: "pending",
        },
      ],
    },
  ],
  nextMilestone: {
    title: "Canal de WhatsApp operativo",
    detail:
      "Alta de Meta Business, configuración de credenciales y primera prueba conversacional de punta a punta.",
    window: "Próxima etapa",
  },
  resources: [
    {
      label: "App web de Dardito",
      detail: "Abrir la aplicación publicada",
      url: "https://dardito-742d2.web.app",
    },
  ],
};

function headerValue(value: string | string[] | undefined, limit: number): string {
  return (Array.isArray(value) ? value[0] ?? "" : value ?? "").slice(0, limit);
}

function clientIp(rawRequest: {
  ip?: string;
  headers: Record<string, string | string[] | undefined>;
}): string {
  if (rawRequest.ip) return rawRequest.ip;
  const forwarded = headerValue(rawRequest.headers["x-forwarded-for"], 300);
  return forwarded.split(",")[0]?.trim() || "unknown";
}

function sanitizedClient(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const input = value as Record<string, unknown>;
  const keys = [
    "timezone",
    "language",
    "languages",
    "platform",
    "mobile",
    "browserBrands",
    "screenWidth",
    "screenHeight",
    "viewportWidth",
    "viewportHeight",
    "pixelRatio",
    "touchPoints",
    "cookiesEnabled",
    "localTime",
  ];
  const result: Record<string, unknown> = {};
  for (const key of keys) {
    const item = input[key];
    if (typeof item === "string") result[key] = item.slice(0, 300);
    else if (typeof item === "number" && Number.isFinite(item)) result[key] = item;
    else if (typeof item === "boolean") result[key] = item;
    else if (Array.isArray(item)) {
      result[key] = item
        .filter((entry): entry is string => typeof entry === "string")
        .slice(0, 8)
        .map((entry) => entry.slice(0, 120));
    }
  }
  return result;
}

export const verifyMppAccess = onCall(
  {
    region,
    cors: allowedMppOrigins,
    timeoutSeconds: 20,
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    const token = request.auth?.token;
    const rawEmail = typeof token?.email === "string" ? token.email.trim() : "";
    const email = rawEmail.toLowerCase();
    const provider = token?.firebase?.sign_in_provider;

    if (
      !request.auth ||
      !email ||
      token?.email_verified !== true ||
      provider !== "google.com"
    ) {
      throw new HttpsError(
        "unauthenticated",
        "Necesitás una cuenta de Google con correo verificado.",
      );
    }

    const ip = clientIp(request.rawRequest);
    try {
      await Promise.all([
        enforceRateLimit(`mpp-user:${request.auth.uid}`, 12, 60 * 60_000),
        enforceRateLimit(`mpp-ip:${ip}`, 50, 60 * 60_000),
      ]);
    } catch (error) {
      if (error instanceof Error && error.message === "RATE_LIMITED") {
        throw new HttpsError(
          "resource-exhausted",
          "Demasiados intentos. Esperá antes de volver a ingresar.",
        );
      }
      throw error;
    }

    const db = getFirestore();
    const candidates = [...new Set([email, rawEmail])];
    const snapshot = await db
      .collection("verificados")
      .where("mail", "in", candidates)
      .limit(1)
      .get();

    const accessId = db.collection("_ids").doc().id;
    const audit = {
      id: accessId,
      email,
      uid: request.auth.uid,
      provider,
      ip,
      ipHash: privacyHash(`mpp-ip:${ip}`),
      userAgent: headerValue(request.rawRequest.headers["user-agent"], 600),
      language: headerValue(request.rawRequest.headers["accept-language"], 200),
      origin: headerValue(request.rawRequest.headers.origin, 300),
      referrer: headerValue(request.rawRequest.headers.referer, 500),
      country: headerValue(request.rawRequest.headers["x-appengine-country"], 80),
      region: headerValue(request.rawRequest.headers["x-appengine-region"], 120),
      city: headerValue(request.rawRequest.headers["x-appengine-city"], 120),
      client: sanitizedClient(request.data?.client),
      fechaHora: FieldValue.serverTimestamp(),
    };

    if (snapshot.empty) {
      await db.collection("curiosos").add({
        ...audit,
        resultado: "sin_acceso",
        createdAt: FieldValue.serverTimestamp(),
      });
      throw new HttpsError(
        "permission-denied",
        "No tienes acceso.",
        {code: "NO_ACCESS"},
      );
    }

    const verifiedReference = snapshot.docs[0]!.ref;
    await verifiedReference.set({
      acceso: {
        ultimo: audit,
        ultimoAccesoAt: FieldValue.serverTimestamp(),
        cantidad: FieldValue.increment(1),
      },
    }, {merge: true});

    const now = Date.now();
    return {
      authorized: true,
      session: {
        issuedAt: now,
        expiresAt: now + sessionDurationMilliseconds,
        warningSeconds: 30,
      },
      dashboard,
    };
  },
);
