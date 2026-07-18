# Balance+ — Versión alternativa del sitio web (rediseño radical)

## Contexto

Balance+ es un servicio de telemedicina para tratamiento de obesidad (GLP-1) en Chile.
El sitio actual vive en `web/` (10 páginas HTML, más `admin.html` y `bp-test.html` en la
raíz del proyecto) con un sistema visual navy (`#1B2D5E`) / sage (`#8AB090`), tipografía
Inter, y lógica real conectada a Supabase (`bp-supabase.js`) y a un banner de cookies
propio (`bp-cookies.js`).

Se pidió una versión alternativa completa del sitio, aplicando las skills/plugins de
UX-UI disponibles, manteniendo consistencia visual entre páginas (como el original),
sin borrar ni modificar nada existente.

## Objetivo

Rediseño radical (paleta, tipografía y lenguaje visual pueden cambiar respecto al
original) del sitio Balance+, ejecutado en dos fases. Este documento cubre **Fase 1**
en detalle; Fase 2 se deja planteada pero no planificada en detalle todavía.

## Alcance

**Incluido (eventualmente, a través de ambas fases):** las 10 páginas HTML del
producto — `web/index.html`, `web/portal.html`, `web/intake.html`, `web/blog.html`,
`web/articulo.html`, `web/contacto.html`, `web/legal.html`, `web/proveedores.html`,
`admin.html` (raíz), `bp-test.html` (raíz).

**Excluido:** documentos legales (`.docx`), esquemas SQL, archivos `.md` de contexto
del proyecto — no son superficie de UI.

## No-destructivo

Todo el trabajo ocurre en una carpeta nueva `web-alt/` en la raíz del proyecto,
hermana de `web/`. `web/` y el resto del repo quedan intactos. `web-alt/` contiene
copias sin modificar de los assets compartidos (imágenes, `bp-cookies.js`,
`bp-supabase.js`, `blog-data.js`) más el HTML/CSS nuevo que se va construyendo.

## Fase 1 — Sistema de diseño + piloto (`index.html`)

1. **Design consultation**: usar la skill `design-consultation` (gstack) para investigar
   el posicionamiento de Balance+ (telemedicina médica, confianza, Chile, GLP-1) y
   proponer 2-3 direcciones visuales completas (estética, tipografía, paleta, layout,
   spacing, motion) distintas del navy/sage actual. El usuario elige una dirección.
2. **Construcción del piloto**: reconstruir `web-alt/index.html` (HTML + CSS) completo
   con la dirección elegida, usando `ui-ux-pro-max` / `frontend-design` para la
   ejecución visual, manteniendo el mismo copy y contenido del original.
3. **QA de diseño**: pasar `design-review` sobre el piloto para pulir inconsistencias
   visuales, espaciado, jerarquía y accesibilidad antes de mostrarlo.
4. **Aprobación**: el usuario revisa el piloto antes de escalar a Fase 2.

### Restricciones funcionales duras (detectadas en `index.html`)

- La calculadora de IMC embebida depende de estos IDs exactos en el DOM:
  `weight-input`, `height-input`, `result-range`, `bmi-before`, `bmi-after`.
  El nuevo HTML debe conservar estos IDs (o el JS debe actualizarse en conjunto) y
  el mismo contrato de `localStorage['bp_calc']` (`{ weight, height, targetWeight }`),
  que **`intake.html` consume después** para prellenar valores.
- `bp-cookies.js` se incluye tal cual, sin modificar; inyecta su propio banner via
  IDs (`bp-cc-accept`, `bp-cc-reject`, `bp-cookie-banner`, `bp-cookie-style`) que no
  dependen de HTML preexistente, así que no hay conflicto con el rediseño.
- El copy/contenido de la página no cambia — solo estructura visual y CSS.
- No se toca la lógica de Supabase (no aplica a `index.html`, pero es la regla general
  para páginas futuras en Fase 2: la funcionalidad JS/Supabase se preserva, solo
  cambia el diseño visual).

## Fase 2 — Rollout al resto de páginas (fuera de alcance de este spec)

Una vez aprobado el piloto, se planificará por separado la extensión del sistema de
diseño aprobado a las 9 páginas restantes. Dado que la mayoría son independientes
entre sí una vez fijado el sistema (componentes, tokens, tipografía), es candidato
natural para ejecución con subagentes en paralelo. Páginas con mayor complejidad de
preservación funcional: `intake.html` (formulario largo + localStorage), `portal.html`
(252KB, probablemente lógica Supabase extensa), `admin.html` (79KB).

## Fuera de alcance

- No se modifica ni se borra nada en `web/` ni en la raíz del proyecto fuera de crear
  `web-alt/`.
- No se cambia la integración de Supabase ni el backend.
- No se decide en este documento el sistema de diseño final — eso es resultado de la
  consulta de diseño en el paso 1 de Fase 1.
