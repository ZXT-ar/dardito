import {loadSiteReport, type SiteReport} from "./site-report.js";
import {FieldPath, getFirestore} from "firebase-admin/firestore";
import PDFDocument from "pdfkit";

export const reportSections = ["audience", "activity", "content", "daily", "website"] as const;
export type ReportSection = typeof reportSections[number];
export function reportRange(from: unknown, to: unknown): {from: string; to: string} {
  const valid = (value: unknown): value is string => typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value;
  if (!valid(from) || !valid(to) || from > to || to > new Date().toISOString().slice(0, 10) || (Date.parse(to) - Date.parse(from)) / 86400000 > 365) throw new Error("Seleccioná fechas válidas, hasta hoy y con un máximo de 366 días.");
  return {from, to};
}
export function selectedSections(value: unknown): ReportSection[] {
  if (!Array.isArray(value) || !value.length || value.some((s) => !reportSections.includes(s))) throw new Error("Seleccioná al menos una sección válida.");
  return [...new Set(value)] as ReportSection[];
}
const number = (value: unknown) => typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : 0;
export async function loadGeneralReport(from: string, to: string, generatedBy: string) {
  reportRange(from, to);
  const website: SiteReport | {status: "unavailable"} = await loadSiteReport(from, to).catch(() => ({status: "unavailable" as const}));
  const db = getFirestore();
  const cap = 20000;
  const [days, sessions, views, stories] = await Promise.all([
    db.collection("analytics_daily").where(FieldPath.documentId(), ">=", from).where(FieldPath.documentId(), "<=", to).get(),
    db.collection("analytics_sessions").where("day", ">=", from).where("day", "<=", to).limit(cap + 1).get(),
    db.collection("analytics_story_daily").where("day", ">=", from).where("day", "<=", to).limit(cap + 1).get(),
    db.collection("knowledge").select("title", "status", "category", "neighborhood", "likeCount").limit(cap + 1).get(),
  ]);
  if ([sessions, views, stories].some((s) => s.size > cap)) throw new Error("El período supera el límite de lectura segura. Reducí el rango de fechas.");
  const daily = days.docs.map((d) => {
    const v = d.data();
    return {date: d.id, sessions: number(v.sessions), chats: number(v.request_chat), storyViews: number(v.storyViews), requests: number(v.requestsTotal), submissions: number(v.request_storySubmissions), errors: number(v.errors)};
  }).sort((a, b) => a.date.localeCompare(b.date));
  const totals = daily.reduce((a, d) => ({sessions: a.sessions + d.sessions, chats: a.chats + d.chats, storyViews: a.storyViews + d.storyViews, requests: a.requests + d.requests, submissions: a.submissions + d.submissions, errors: a.errors + d.errors}), {sessions: 0, chats: 0, storyViews: 0, requests: 0, submissions: 0, errors: 0});
  const durations = sessions.docs.map((d) => d.data().durationSeconds).filter((n): n is number => typeof n === "number" && Number.isFinite(n) && n >= 0);
  const ranking = new Map<string, {title: string; views: number}>();
  for (const d of views.docs) { const v = d.data(); const key = String(v.storyId); const previous = ranking.get(key); ranking.set(key, {title: String(v.title ?? "Sin título"), views: (previous?.views ?? 0) + number(v.views)}); }
  const published = stories.docs.filter((d) => d.data().status === "published");
  const categories: Record<string, number> = Object.create(null);
  for (const d of published) {const label = String(d.data().category ?? "Sin categoría"); categories[label] = (categories[label] ?? 0) + 1;}
  return {
    from, to, generatedBy, generatedAt: new Date().toISOString(), daily, totals,
    website, observedDays: daily.length,
    durationSamples: durations.length,
    averageDuration: durations.length ? Math.round(durations.reduce((a, b) => a + b, 0) / durations.length) : null,
    uniqueVisitors: null, returningVisitors: null,
    content: {total: stories.size, published: published.length, likes: published.reduce((sum, d) => sum + number(d.data().likeCount), 0), categories},
    topLiked: published.map((d) => ({title: String(d.data().title ?? "Sin título"), likes: number(d.data().likeCount)})).sort((a, b) => b.likes - a.likes).slice(0, 10),
    topViewed: [...ranking.values()].sort((a, b) => b.views - a.views).slice(0, 10),
    notes: ["Fechas y agrupación diaria en UTC. Los días sin registros no se interpretan como cero actividad.", "Las sesiones internas y la medición del sitio completo tienen alcances distintos; sus cifras no deben sumarse.", "Duración observada por señales de actividad; no es tiempo de atención. Sesiones con retención de hasta 90 días; la media solo usa los registros disponibles.", "Historias y likes representan el estado actual de las historias publicadas.", "Las métricas reflejan los eventos recibidos por el servidor, sujetos a interrupciones de conexión y cobertura de la instrumentación."],
  };
}
export type GeneralReport = Awaited<ReturnType<typeof loadGeneralReport>>;
export function generalReportFilename(report: GeneralReport) {
  const author = report.generatedBy.replace(/[^a-zA-Z0-9@._-]/g, "_").slice(0, 100);
  return `El_Mapa_de_las_Historias_de_La_Plata_${report.generatedAt.replace(/[:.]/g, "-")}_${author}.pdf`;
}
export async function createGeneralReportPdf(report: GeneralReport, sections: ReportSection[]): Promise<Buffer> {
  selectedSections(sections);
  const doc = new PDFDocument({size: "A4", margin: 44, bufferPages: true, info: {Title: "El Mapa de las Historias de La Plata", Author: report.generatedBy, Subject: "Informe general de actividad"}});
  const chunks: Buffer[] = [];
  const result = new Promise<Buffer>((resolve, reject) => { doc.on("data", (b) => chunks.push(b)); doc.on("end", () => resolve(Buffer.concat(chunks))); doc.on("error", reject); });
  const heading = (title: string) => {doc.font("Helvetica-Bold").fontSize(22).fillColor("#0a222d").text(title); doc.moveDown(0.6);};
  const text = (value: string) => {doc.font("Helvetica").fontSize(10).fillColor("#45565e").text(value, {lineGap: 4}); doc.moveDown(0.5);};
  const stat = (label: string, value: number | string) => {doc.font("Helvetica-Bold").fontSize(13).fillColor("#0a222d").text(`${label}: ${value}`); doc.moveDown(0.6);};
  const bars = (rows: {label: string; value: number}[]) => {
    const max = Math.max(1, ...rows.map((r) => r.value));
    for (const row of rows) {
      if (doc.y > 710) {doc.addPage(); heading("Detalle · continuación");}
      doc.font("Helvetica").fontSize(10).fillColor("#172126").text(`${row.label} · ${row.value.toLocaleString("es-AR")}`, {width: 500});
      const y = doc.y + 5;
      doc.rect(44, y, 500, 7).fill("#edf0ed"); if (row.value) doc.rect(44, y, 500 * row.value / max, 7).fill("#4d7357");
      doc.y = y + 23;
    }
  };
  heading("El Mapa de las\nHistorias de La Plata");
  doc.rect(44, doc.y, 70, 5).fill("#f7bd00"); doc.moveDown(1.5);
  heading("Informe de actividad");
  text(`Período: ${report.from} al ${report.to} (UTC)`);
  text(`Generado: ${new Date(report.generatedAt).toLocaleString("es-AR", {timeZone: "America/Argentina/Buenos_Aires"})} (Argentina)`);
  text(`Generado por: ${report.generatedBy}`);
  text(`Fuente: registros de actividad del proyecto. ${report.observedDays} días con registros en el período.`);
  heading("Alcance y metodología");
  report.notes.forEach((note) => {
    doc.font("Helvetica").fontSize(10).fillColor("#45565e").text(note, {lineGap: 4, align: "justify"});
    doc.moveDown(0.5);
  });
  if (sections.includes("website")) {
    doc.addPage(); heading("Sitio web completo");
    const site = report.website;
    if (!site || site.status !== "available") text("La medición del sitio completo no está disponible en esta consulta.");
    else {
      text(`Período según la zona horaria ${site.timeZone}. Las cifras recientes pueden actualizarse.`);
      stat("Visitantes únicos", site.totals.totalUsers); stat("Visitantes nuevos", site.totals.newUsers); stat("Visitantes recurrentes", site.totals.returningUsers);
      stat("Sesiones", site.totals.sessions); stat("Vistas de páginas", site.totals.screenPageViews);
      stat("Sesiones con interacción", site.totals.engagedSessions); stat("Tasa de interacción", `${(site.totals.engagementRate * 100).toFixed(1)}%`);
      stat("Interacción media por sesión", site.averageEngagementSeconds === null ? "No disponible" : `${Math.round(site.averageEngagementSeconds)} segundos`);
      text("Los visitantes se identifican según las señales disponibles. Nuevos y recurrentes pueden coincidir dentro del mismo período; no deben sumarse. Ubicación aproximada.");
      if (site.limited) text("Algunos resultados están sujetos a umbrales o muestreo.");
      for (const [title, rows] of [["Sesiones por día", site.daily], ["Canales de llegada · sesiones", site.channels], ["Dispositivos · sesiones", site.devices], ["Países · visitantes", site.countries], ["Páginas más vistas", site.pages]] as const) {
        doc.addPage(); heading(title); if (!rows.length) text("Sin registros en el período."); bars(rows);
      }
    }
  }
  if (sections.includes("audience")) {
    doc.addPage(); heading("01 · Audiencia y sesiones");
    stat("Sesiones registradas", report.totals.sessions); stat("Duración media observada", report.averageDuration === null ? "No disponible" : `${report.averageDuration} segundos`);
    text(`Base de la media: ${report.durationSamples} sesiones con duración disponible.`);

    heading("Sesiones por día"); bars(report.daily.map((d) => ({label: d.date, value: d.sessions})));
  }
  if (sections.includes("activity")) {
    doc.addPage(); heading("02 · Actividad del mapa");
    stat("Lecturas de historias", report.totals.storyViews); stat("Solicitudes al chat", report.totals.chats); stat("Solicitudes de aportes", report.totals.submissions); stat("Solicitudes a la API", report.totals.requests); stat("Errores registrados", report.totals.errors);
    heading("Historias más leídas en el período"); if (!report.topViewed.length) text("Sin registros de lecturas en el período."); bars(report.topViewed.map((r) => ({label: r.title, value: r.views})));
  }
  if (sections.includes("content")) {
    doc.addPage(); heading("03 · Patrimonio editorial actual"); text("Fotografía actual; estas cifras no se filtran por fecha.");
    stat("Historias en el corpus", report.content.total); stat("Historias publicadas", report.content.published); stat("Likes en historias publicadas", report.content.likes);
    heading("Historias con más likes"); bars(report.topLiked.map((r) => ({label: r.title, value: r.likes})));
    doc.addPage(); heading("Historias publicadas por categoría"); bars(Object.entries(report.content.categories).map(([label, value]) => ({label, value})));
  }
  if (sections.includes("daily")) {
    const tableHeader = () => {
      doc.addPage(); heading("04 · Detalle diario");
      const y = doc.y;
      doc.rect(44, y, 507, 24).fill("#edf0ed");
      ["Fecha UTC", "Sesiones", "Lecturas", "Chat", "Aportes", "API", "Errores"].forEach((label, i) => doc.font("Helvetica-Bold").fontSize(9).fillColor("#0a222d").text(label, 50 + (i === 0 ? 0 : 96 + (i - 1) * 67), y + 7, {width: i === 0 ? 90 : 62, lineBreak: false}));
      doc.x = 44; doc.y = y + 32;
    };
    tableHeader();
    if (!report.daily.length) text("Sin registros para el período seleccionado.");
    for (const d of report.daily) {
      if (doc.y > 730) tableHeader();
      const y = doc.y;
      [d.date, d.sessions, d.storyViews, d.chats, d.submissions, d.requests, d.errors].forEach((value, i) => doc.font("Helvetica").fontSize(9).fillColor("#45565e").text(String(value), 50 + (i === 0 ? 0 : 96 + (i - 1) * 67), y, {width: i === 0 ? 90 : 62, lineBreak: false}));
      doc.moveTo(44, y + 16).lineTo(551, y + 16).strokeColor("#edf0ed").stroke();
      doc.x = 44; doc.y = y + 23;
    }
  }
  const pages = doc.bufferedPageRange();
  for (let i = 0; i < pages.count; i++) {doc.switchToPage(i); doc.font("Helvetica").fontSize(8).fillColor("#68747a").text(`El Mapa de las Historias de La Plata · ${i + 1} / ${pages.count}`, 44, 785, {lineBreak: false});}
  doc.end(); return result;
}
