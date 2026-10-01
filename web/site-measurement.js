(() => {
  'use strict';
  if (!['darditohistoriasplatenses.com', 'www.darditohistoriasplatenses.com'].includes(location.hostname)) return;
  const id = 'G-63Z7EYPDSQ';
  window.dataLayer = window.dataLayer || [];
  function gtag() { window.dataLayer.push(arguments); }
  gtag('js', new Date());
  gtag('config', id, {send_page_view: false, allow_google_signals: false, allow_ad_personalization_signals: false});
  const script = document.createElement('script');
  script.async = true;
  script.src = 'https://www.googletagmanager.com/gtag/js?id=' + id;
  document.head.appendChild(script);
  const labels = ['Inicio', 'Explorar historias', 'Asistente', 'Compartir historia', 'Términos y políticas', 'Condiciones del servicio', 'Eliminación de datos'];
  let previous = null;
  window.mhdlpMeasureSection = function (section) {
    if (!Number.isInteger(section) || !labels[section] || section === previous) return;
    previous = section;
    // Send only known section names: never chat text, emails or arbitrary URLs.
    gtag('event', 'page_view', {page_title: labels[section], page_location: location.origin + '/?section=' + section, page_referrer: document.referrer ? new URL(document.referrer).origin : ''});
  };
  const path = location.pathname.replace(/\/$/, '');
  const legal = {'/terminos_y_politicas': 4, '/condiciones_del_servicio': 5, '/eliminacion_de_datos': 6};
  if (Object.prototype.hasOwnProperty.call(legal, path)) window.mhdlpMeasureSection(legal[path]);
})();
