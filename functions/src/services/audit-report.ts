import PDFDocument from "pdfkit";

export type AuditReportKind = "filtered" | "stories_by_user" | "approvals_by_user";

export interface AuditReportRow {
  action: string;
  actorEmail: string;
  actorRole: string;
  target: string;
  createdAt: string;
}

export interface AuditRankingRow {
  email: string;
  count: number;
}

export interface AuditReportInput {
  kind: AuditReportKind;
  title: string;
  subtitle: string;
  generatedBy: string;
  filtersLabel: string;
  rows: AuditReportRow[];
  ranking: AuditRankingRow[];
  total: number;
}

const colors = {
  navy: "#071F2A",
  ink: "#172126",
  muted: "#66757C",
  line: "#D6D8D2",
  cream: "#F7F3E9",
  yellow: "#F8BE00",
  green: "#537258",
  white: "#FFFFFF",
};

function actionLabel(action: string): string {
  const labels: Record<string, string> = {
    "knowledge.created": "Historia creada",
    "knowledge.updated": "Historia actualizada",
    "knowledge.transitioned": "Estado editorial modificado",
    "submission.request_info": "Informacion solicitada",
    "submission.reject": "Aporte rechazado",
    "submission.convert": "Aporte aprobado",
    "catalogs.updated": "Catalogos actualizados",
    "resource.created": "Recurso incorporado",
    "resource.uploaded": "Archivo cargado",
    "resource.upload_discarded": "Carga descartada",
    "resource.updated": "Recurso actualizado",
    "resource.deleted": "Recurso eliminado",
    "resource.extraction_completed": "Extracción documental completada",
    "resource.extraction_failed": "Extracción documental fallida",
    "session.started": "Inicio de sesion",
    "editorial_access.invited": "Cuenta habilitada",
    "editorial_access.activated": "Cuenta activada",
    "editorial_access.confirmed": "Acceso confirmado",
    "editorial_access.role_changed": "Rol modificado",
    "editorial_access.revoked": "Acceso revocado",
  };
  return labels[action] ?? action;
}

function formatDate(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("es-AR", {
    dateStyle: "short",
    timeStyle: "short",
    timeZone: "America/Argentina/Buenos_Aires",
  }).format(date);
}

function footer(document: PDFKit.PDFDocument): void {
  const range = document.bufferedPageRange();
  for (let index = range.start; index < range.start + range.count; index += 1) {
    document.switchToPage(index);
    document
      .font("Helvetica")
      .fontSize(8)
      .fillColor(colors.muted)
      .text("El Mapa de las Historias de La Plata - Informe administrativo", 44, 806, {width: 410});
    document.text(`Pagina ${index + 1} de ${range.count}`, 470, 806, {width: 80, align: "right"});
  }
}

function ensureSpace(document: PDFKit.PDFDocument, height: number): void {
  if (document.y + height > 790) document.addPage();
}

function drawHeader(document: PDFKit.PDFDocument, input: AuditReportInput): void {
  document.rect(0, 0, 595.28, 122).fill(colors.navy);
  document.rect(44, 38, 10, 10).fill(colors.yellow);
  document
    .font("Helvetica-Bold")
    .fontSize(10)
    .fillColor(colors.yellow)
    .text("AUDITORIA EDITORIAL", 66, 37, {characterSpacing: 1.4});
  document.font("Helvetica-Bold").fontSize(23).fillColor(colors.white).text(input.title, 44, 64, {width: 507});
  document.font("Helvetica").fontSize(9).fillColor("#C8D0D4").text(input.subtitle, 44, 96, {width: 507});
  document.y = 148;
}

function drawSummary(document: PDFKit.PDFDocument, input: AuditReportInput): void {
  const cards = [
    {label: "REGISTROS", value: String(input.total)},
    {label: "GENERADO POR", value: input.generatedBy || "Administrador"},
    {label: "CRITERIO", value: input.filtersLabel},
  ];
  const width = 161;
  cards.forEach((card, index) => {
    const x = 44 + index * 173;
    document.roundedRect(x, 145, width, 65, 3).fillAndStroke(colors.cream, colors.line);
    document.font("Helvetica-Bold").fontSize(7).fillColor(colors.muted).text(card.label, x + 12, 157, {width: width - 24});
    document.font("Helvetica-Bold").fontSize(index === 0 ? 19 : 9).fillColor(colors.ink).text(card.value, x + 12, 176, {
      width: width - 24,
      height: 24,
      ellipsis: true,
    });
  });
  document.y = 235;
}

function drawRanking(document: PDFKit.PDFDocument, input: AuditReportInput): void {
  document.font("Helvetica-Bold").fontSize(15).fillColor(colors.ink).text("Distribucion por usuario", 44, document.y);
  document.moveDown(0.7);
  if (input.ranking.length === 0) {
    document.font("Helvetica").fontSize(10).fillColor(colors.muted).text("No se encontraron movimientos para el periodo seleccionado.");
    return;
  }
  const maximum = Math.max(...input.ranking.map((item) => item.count), 1);
  input.ranking.slice(0, 12).forEach((item, index) => {
    ensureSpace(document, 42);
    const y = document.y;
    const barWidth = Math.max(8, 300 * (item.count / maximum));
    document.font("Helvetica-Bold").fontSize(9).fillColor(colors.ink).text(`${index + 1}. ${item.email}`, 44, y, {width: 350, ellipsis: true});
    document.font("Helvetica-Bold").fontSize(10).fillColor(colors.green).text(String(item.count), 510, y, {width: 40, align: "right"});
    document.roundedRect(44, y + 17, 420, 8, 4).fill("#E6E5DE");
    document.roundedRect(44, y + 17, barWidth, 8, 4).fill(index === 0 ? colors.yellow : colors.green);
    document.y = y + 38;
  });
}

function drawRows(document: PDFKit.PDFDocument, input: AuditReportInput): void {
  document.font("Helvetica-Bold").fontSize(15).fillColor(colors.ink).text("Detalle de movimientos", 44, document.y);
  document.moveDown(0.6);
  const columns = [44, 150, 312, 436];
  const widths = [100, 156, 118, 115];
  const headerY = document.y;
  document.rect(44, headerY, 507, 25).fill(colors.navy);
  ["Fecha", "Usuario", "Accion", "Objetivo"].forEach((label, index) => {
    document.font("Helvetica-Bold").fontSize(7).fillColor(colors.white).text(label.toUpperCase(), columns[index] ?? 44, headerY + 9, {width: widths[index] ?? 100});
  });
  document.y = headerY + 25;
  input.rows.forEach((row, index) => {
    ensureSpace(document, 39);
    const y = document.y;
    if (index % 2 === 0) document.rect(44, y, 507, 35).fill("#FBFAF6");
    const values = [formatDate(row.createdAt), row.actorEmail || "Sistema", actionLabel(row.action), row.target];
    values.forEach((value, columnIndex) => {
      document.font(columnIndex === 2 ? "Helvetica-Bold" : "Helvetica").fontSize(7.5).fillColor(colors.ink).text(value, columns[columnIndex] ?? 44, y + 9, {
        width: widths[columnIndex] ?? 100,
        height: 20,
        ellipsis: true,
      });
    });
    document.moveTo(44, y + 35).lineTo(551, y + 35).strokeColor(colors.line).lineWidth(0.5).stroke();
    document.y = y + 35;
  });
}

export async function createAuditReport(input: AuditReportInput): Promise<Buffer> {
  const document = new PDFDocument({size: "A4", margins: {top: 44, right: 44, bottom: 50, left: 44}, bufferPages: true, info: {
    Title: input.title,
    Author: "Simbiosis Digital",
    Subject: "Auditoria editorial",
  }});
  const chunks: Buffer[] = [];
  document.on("data", (chunk: Buffer) => chunks.push(chunk));
  const completed = new Promise<Buffer>((resolve, reject) => {
    document.on("end", () => resolve(Buffer.concat(chunks)));
    document.on("error", reject);
  });
  drawHeader(document, input);
  drawSummary(document, input);
  if (input.kind === "filtered") drawRows(document, input);
  else drawRanking(document, input);
  footer(document);
  document.end();
  return completed;
}
