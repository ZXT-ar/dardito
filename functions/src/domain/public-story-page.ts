import type {PublicStory} from "./public-story.js";

export const publicSiteOrigin = "https://dardito-742d2.web.app";
export const publicSiteName = "El Mapa de las Historias de La Plata";
export const fallbackSocialImage = `${publicSiteOrigin}/assets/assets/brand/mhdlp_logo_horizontal.jpg`;

export function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function safeJson(value: unknown): string {
  return JSON.stringify(value).replaceAll("<", "\\u003c");
}

export function storyPublicUrl(id: string): string {
  return `${publicSiteOrigin}/historias/${encodeURIComponent(id)}`;
}

export function storyImageUrl(id: string): string {
  return `${publicSiteOrigin}/api/story-images/${encodeURIComponent(id)}`;
}

export function createStoryHtml(story: PublicStory, hasAuthorizedImage: boolean): string {
  const canonical = storyPublicUrl(story.id);
  const image = hasAuthorizedImage ? storyImageUrl(story.id) : fallbackSocialImage;
  const appUrl = `${publicSiteOrigin}/?section=explore&story=${encodeURIComponent(story.id)}`;
  const title = `${story.title} | ${publicSiteName}`;
  const description = story.summary.slice(0, 300);
  const contributionLabel = story.contributionOrigin === "community"
    ? `Aporte de: ${story.publicAuthor ?? "Un usuario"}`
    : "Proporcionada por el equipo de Dardito";
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: story.title,
    description,
    image: [image],
    inLanguage: "es-AR",
    mainEntityOfPage: canonical,
    about: {
      "@type": "Place",
      name: story.neighborhood,
      geo: {
        "@type": "GeoCoordinates",
        latitude: story.latitude,
        longitude: story.longitude,
      },
    },
    publisher: {
      "@type": "Organization",
      name: publicSiteName,
      url: publicSiteOrigin,
      logo: {
        "@type": "ImageObject",
        url: `${publicSiteOrigin}/icons/Icon-512.png`,
      },
    },
  };

  return `<!doctype html>
<html lang="es-AR" prefix="og: https://ogp.me/ns# article: https://ogp.me/ns/article#">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <meta name="description" content="${escapeHtml(description)}">
  <meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1">
  <link rel="canonical" href="${escapeHtml(canonical)}">
  <meta property="og:locale" content="es_AR">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="${escapeHtml(publicSiteName)}">
  <meta property="og:title" content="${escapeHtml(story.title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:url" content="${escapeHtml(canonical)}">
  <meta property="og:image" content="${escapeHtml(image)}">
  <meta property="og:image:secure_url" content="${escapeHtml(image)}">
  <meta property="og:image:alt" content="${escapeHtml(`Imagen de ${story.title}`)}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapeHtml(story.title)}">
  <meta name="twitter:description" content="${escapeHtml(description)}">
  <meta name="twitter:image" content="${escapeHtml(image)}">
  <meta name="theme-color" content="#F4B900">
  <link rel="icon" href="/favicon.png">
  <script type="application/ld+json">${safeJson(structuredData)}</script>
  <style>
    :root{color-scheme:light;--navy:#071d28;--paper:#fbf8ef;--yellow:#f4b900;--ink:#171815;--muted:#69675f}
    *{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:Arial,sans-serif}
    main{min-height:100vh;display:grid;grid-template-columns:minmax(0,1.05fr) minmax(320px,.95fr)}
    .story{padding:clamp(32px,7vw,108px);display:flex;flex-direction:column;justify-content:center;max-width:980px}
    .brand{width:min(410px,100%);height:auto;margin-bottom:56px}.eyebrow{color:#8d6a00;font-weight:800;letter-spacing:.14em;text-transform:uppercase}
    h1{font-family:Georgia,serif;font-size:clamp(44px,7vw,92px);line-height:.98;margin:18px 0 28px}.lead{font-size:clamp(19px,2vw,27px);line-height:1.55;color:var(--muted);max-width:760px}
    .facts{display:flex;flex-wrap:wrap;gap:10px;margin:32px 0}.fact{border:1px solid #d8d0bf;padding:10px 14px;background:#fff}
    .origin{display:inline-flex;align-self:flex-start;margin-top:18px;padding:9px 12px;background:#fff4c9;border:1px solid #dcc45a;color:#624f00;font-size:13px;font-weight:800}
    .cta{align-self:flex-start;background:var(--ink);color:#fff;text-decoration:none;font-weight:800;padding:16px 24px;margin-top:14px}.visual{background:var(--navy);display:flex;align-items:center;justify-content:center;padding:40px}
    .visual img{width:min(620px,100%);max-height:76vh;object-fit:contain;background:#fff}
    @media(max-width:820px){main{grid-template-columns:1fr}.story{padding:34px 24px 42px}.brand{margin-bottom:34px}.visual{min-height:320px}.visual img{max-height:52vh}}
  </style>
</head>
<body>
  <main>
    <article class="story">
      <img class="brand" src="/assets/assets/brand/mhdlp_logo_horizontal.jpg" alt="${escapeHtml(publicSiteName)}">
      <div class="eyebrow">${escapeHtml(story.categoryLabel)} · ${escapeHtml(story.neighborhood)}</div>
      <h1>${escapeHtml(story.title)}</h1>
      <p class="lead">${escapeHtml(description)}</p>
      <span class="origin">${escapeHtml(contributionLabel)}</span>
      <div class="facts">
        <span class="fact">${escapeHtml(story.period)}</span>
        <span class="fact">${escapeHtml(story.evidenceLabel)}</span>
        <span class="fact">${story.readingMinutes} min de lectura</span>
      </div>
      <a class="cta" href="${escapeHtml(appUrl)}">Abrir historia en el mapa</a>
    </article>
    <div class="visual"><img src="${escapeHtml(image)}" alt="${escapeHtml(`Imagen de ${story.title}`)}"></div>
  </main>
</body>
</html>`;
}

export function createNotFoundHtml(): string {
  return `<!doctype html><html lang="es-AR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>Historia no encontrada | ${publicSiteName}</title></head><body><main><h1>Esta historia no está disponible.</h1><p>Puede haber sido archivada o todavía no estar publicada.</p><a href="${publicSiteOrigin}/?section=explore">Explorar historias publicadas</a></main></body></html>`;
}

export function createSitemapXml(stories: Array<{id: string; lastModified?: string}>): string {
  const pages = [
    {url: `${publicSiteOrigin}/`, lastModified: undefined},
    {url: `${publicSiteOrigin}/?section=explore`, lastModified: undefined},
    ...stories.map((story) => ({url: storyPublicUrl(story.id), lastModified: story.lastModified})),
  ];
  const entries = pages.map((page) => `  <url>\n    <loc>${escapeHtml(page.url)}</loc>${page.lastModified ? `\n    <lastmod>${escapeHtml(page.lastModified)}</lastmod>` : ""}\n  </url>`).join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${entries}\n</urlset>`;
}
