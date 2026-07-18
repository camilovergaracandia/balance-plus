/* ============================================================================
 * bp-cookies.js — Banner de consentimiento de cookies (Balance+)
 *
 * Banner simple y compatible con Ley 21.719 / Política de Cookies:
 *  - Opt-in: analítica/marketing NO se cargan hasta que la persona ACEPTA.
 *  - "Rechazar" al mismo nivel que "Aceptar".
 *  - Guarda la elección y la fecha en localStorage.
 *  - Enlace a la Política de Cookies.
 *
 * Uso: agregar en cada página  <script src="bp-cookies.js"></script>
 *
 * IMPORTANTE (legal): este banner habilita analítica/marketing, pero NO
 * legaliza el uso de datos de salud para retargeting. El texto y las cookies
 * declaradas deben validarse con el DPO. Completar la Política de Cookies.
 * ========================================================================== */

(function () {
  'use strict';
  var KEY = 'bp_cookie_consent';
  var POLICY_URL = 'legal.html';   // página con la Política de Cookies

  function getConsent() {
    try { return JSON.parse(localStorage.getItem(KEY)); } catch (e) { return null; }
  }
  function setConsent(choice) {
    try { localStorage.setItem(KEY, JSON.stringify({ choice: choice, date: new Date().toISOString() })); } catch (e) {}
  }

  /* Scripts que SOLO deben correr con consentimiento (analítica/marketing).
     Hoy está vacío: aquí irían Google Analytics, píxeles, etc. cuando los uses. */
  function loadConsentedScripts() {
    // Ejemplo (no activo): cargar Google Analytics aquí solo si choice === 'accepted'.
    // window.dataLayer = window.dataLayer || []; ...
  }

  function removeBanner() {
    var b = document.getElementById('bp-cookie-banner');
    if (b && b.parentNode) b.parentNode.removeChild(b);
  }

  function injectStyles() {
    if (document.getElementById('bp-cookie-style')) return;
    var css = ''
      + '#bp-cookie-banner{position:fixed;left:0;right:0;bottom:0;z-index:99999;'
      + 'background:#1B2D5E;color:#fff;padding:16px 20px;box-shadow:0 -4px 20px rgba(0,0,0,.18);'
      + 'font-family:Inter,system-ui,Arial,sans-serif;display:flex;flex-wrap:wrap;align-items:center;'
      + 'gap:12px 18px;justify-content:center}'
      + '#bp-cookie-banner p{margin:0;font-size:13.5px;line-height:1.5;max-width:680px;flex:1 1 340px}'
      + '#bp-cookie-banner a{color:#cfe3d3;text-decoration:underline}'
      + '#bp-cookie-banner .bp-cc-actions{display:flex;gap:10px;flex:0 0 auto}'
      + '#bp-cookie-banner button{cursor:pointer;border:0;border-radius:8px;font-size:13.5px;font-weight:700;'
      + 'padding:10px 18px;font-family:inherit}'
      + '#bp-cookie-banner .bp-cc-accept{background:#8AB090;color:#13251f}'
      + '#bp-cookie-banner .bp-cc-reject{background:transparent;color:#fff;border:1.5px solid rgba(255,255,255,.5)}'
      + '@media(max-width:560px){#bp-cookie-banner{flex-direction:column;align-items:stretch;text-align:center}'
      + '#bp-cookie-banner .bp-cc-actions{justify-content:center}}';
    var s = document.createElement('style');
    s.id = 'bp-cookie-style';
    s.textContent = css;
    document.head.appendChild(s);
  }

  function showBanner() {
    injectStyles();
    if (document.getElementById('bp-cookie-banner')) return;
    var bar = document.createElement('div');
    bar.id = 'bp-cookie-banner';
    bar.setAttribute('role', 'dialog');
    bar.setAttribute('aria-label', 'Aviso de cookies');
    bar.innerHTML =
      '<p>Usamos cookies necesarias para que el sitio funcione y, con tu permiso, '
      + 'cookies de analítica y marketing. Puedes aceptarlas o rechazarlas. '
      + 'Más detalles en nuestra <a href="' + POLICY_URL + '">Política de Cookies</a>.</p>'
      + '<div class="bp-cc-actions">'
      + '<button type="button" class="bp-cc-reject" id="bp-cc-reject">Rechazar</button>'
      + '<button type="button" class="bp-cc-accept" id="bp-cc-accept">Aceptar</button>'
      + '</div>';
    document.body.appendChild(bar);
    document.getElementById('bp-cc-accept').addEventListener('click', function () {
      setConsent('accepted'); removeBanner(); loadConsentedScripts();
    });
    document.getElementById('bp-cc-reject').addEventListener('click', function () {
      setConsent('rejected'); removeBanner();
    });
  }

  function init() {
    var c = getConsent();
    if (!c) { showBanner(); }
    else if (c.choice === 'accepted') { loadConsentedScripts(); }
    // si rechazó: no se carga nada y no se muestra el banner de nuevo.
  }

  // API pública: permite reabrir el banner (p. ej. desde un enlace "Cookies" en el footer).
  window.bpOpenCookiePrefs = function () { showBanner(); };
  window.bpCookieConsent = getConsent;

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
