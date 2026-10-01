import {GoogleAuth} from "google-auth-library";

const auth = new GoogleAuth({scopes: ["https://www.googleapis.com/auth/analytics.readonly"]});
const property = "546491979";
export const siteMetrics = ["totalUsers", "newUsers", "sessions", "screenPageViews", "engagedSessions", "engagementRate", "userEngagementDuration"] as const;
type ApiReport = {rows?: Array<{dimensionValues?: Array<{value?: string}>; metricValues?: Array<{value?: string}>}>; metadata?: {timeZone?: string; subjectToThresholding?: boolean; samplingMetadatas?: unknown[]}};
export function readMetric(value: string | undefined): number {
  const result = Number(value ?? 0);
  if (!Number.isFinite(result) || result < 0) throw new Error("Respuesta de medición inválida");
  return result;
}
export async function loadSiteReport(from: string, to: string) {
  const client = await auth.getClient();
  async function run(metrics: readonly string[], dimension?: string, limit = 10, returning = false): Promise<ApiReport> {
    const response = await client.request<ApiReport>({url: `https://analyticsdata.googleapis.com/v1beta/properties/${property}:runReport`, method: "POST", timeout: 15000, data: {
      dateRanges: [{startDate: from, endDate: to}], metrics: metrics.map(name => ({name})),
      dimensions: dimension ? [{name: dimension}] : [],
      dimensionFilter: {andGroup: {expressions: [
        ...(returning ? [{filter: {fieldName: "newVsReturning", stringFilter: {matchType: "EXACT", value: "returning"}}}] : []),
        {filter: {fieldName: "streamId", stringFilter: {matchType: "EXACT", value: "15316935680"}}},
        {filter: {fieldName: "hostName", inListFilter: {values: ["darditohistoriasplatenses.com", "www.darditohistoriasplatenses.com"]}}},
      ]}}, limit,
      ...(dimension ? {orderBys: dimension === "date" ? [{dimension: {dimensionName: "date"}}] : [{metric: {metricName: metrics[0]}, desc: true}]} : {}),
    }});
    return response.data;
  }
  const [summary, daily, channels, devices, countries, pages, returning] = await Promise.all([
    run(siteMetrics), run(["sessions"], "date", 366), run(["sessions"], "sessionDefaultChannelGroup"),
    run(["sessions"], "deviceCategory"), run(["totalUsers"], "country"), run(["screenPageViews"], "pageTitle"), run(["totalUsers"], undefined, 1, true),
  ]);
  const values = summary.rows?.[0]?.metricValues;
  const totals = {...Object.fromEntries(siteMetrics.map((name, index) => [name, readMetric(values?.[index]?.value)])) as Record<typeof siteMetrics[number], number>, returningUsers: readMetric(returning.rows?.[0]?.metricValues?.[0]?.value)};
  const rows = (report: ApiReport) => (report.rows ?? []).map(row => ({label: row.dimensionValues?.[0]?.value || "Sin clasificar", value: readMetric(row.metricValues?.[0]?.value)}));
  return {status: "available" as const, timeZone: summary.metadata?.timeZone ?? "No informada", totals,
    averageEngagementSeconds: totals.sessions ? totals.userEngagementDuration / totals.sessions : null,
    daily: rows(daily), channels: rows(channels), devices: rows(devices), countries: rows(countries), pages: rows(pages),
    limited: [summary,daily,channels,devices,countries,pages].some(r => r.metadata?.subjectToThresholding || r.metadata?.samplingMetadatas?.length),
  };
}
export type SiteReport = Awaited<ReturnType<typeof loadSiteReport>>;
