# PROJECT BRIEF — Balance+ (Balance Plus)
*Documento de retomada para iniciar una nueva conversación sobre este proyecto sin reiterar decisiones ya tomadas.*

**Última actualización:** 16 de junio de 2026.

## Cómo usar este documento

Este brief resume el estado actual del proyecto para evitar iteraciones repetidas, **no reemplaza la revisión de los archivos**. Antes de proponer cambios o responder preguntas sobre el sitio, abre y lee directamente los archivos relevantes en la carpeta `Balance Plus` — este documento te dice *qué* buscar y *dónde*, pero los valores exactos (textos, CSS, JS) pueden haber cambiado desde que se escribió. Si algo aquí contradice lo que ves en el archivo real, confía en el archivo.

**Instrucción permanente del proyecto:** "Quiero hacer la versión Medvi chilena con foco en Weight Loss" — Balance+ es un sitio estático (HTML/CSS/JS, sin backend) que replica el modelo de plataformas tipo Ro/Hims/Medvi para Chile, enfocado en pérdida de peso con medicamentos GLP-1.

**Reglas permanentes de colaboración (verbatim del usuario, vigentes en todo momento):**
- "No uses más computer-use. Se me pega." → Nunca usar las herramientas `computer-use` (le cuelga el computador al usuario). Esto NO aplica a las herramientas de navegador `Claude in Chrome`, que sí se pueden usar, aunque en este proyecto la navegación a `file://` o `data:` URLs ha fallado, así que la verificación visual de cambios en HTML/CSS no ha sido posible en sesiones anteriores — los cambios de espaciado/alineación se hacen por estimación razonada y se ajustan con el feedback del usuario.
- Dividir el trabajo en piezas pequeñas y verificables — evitar cambios grandes de una sola vez.

---

## 1. Relación entre index.html, contacto.html y legal.html

Las tres páginas comparten exactamente la misma estructura (`<div class="page"> → <nav> → <main> → <section class="col-left"> + <section class="col-right"> → </main> → <footer>`) y el **panel izquierdo (`.col-left`) es idéntico carácter por carácter** entre las tres (verificado con diff: la única diferencia es un comentario HTML que dice qué va en el panel derecho). Esto significa que el hero (badge "Tratamiento médico para bajar de peso", h1, lead, checklist de 4 puntos, CTA "Ver si soy candidato", imagen `hero_collage.png`, y la fila de 3 estadísticas clínicas) se repite igual en las tres páginas.

Lo que cambia es únicamente el **panel derecho (`.col-right`)**:
- **index.html** → Trust bar (3 atributos: Verificación de Identidad / Médicos Verificados / Farmacias Establecidas) + calculadora interactiva de peso/IMC (`.calc-card`) + sección "GLP-1 en Prensa" con 2 tarjetas de noticias (La Tercera, T13 con badge "PRONTO").
- **contacto.html** → Formulario de contacto (`#contactForm`: tipo de solicitud, motivo, detalle, nombre, teléfono, email, botón submit).
- **legal.html** → Lista de 8 tarjetas de documentos descargables (`.doc-card`, docs 01 a 06c en PDF) + botón "Volver al inicio".

El `<nav>` y el `<footer>` también son casi idénticos entre las tres; las diferencias menores detectadas son cosméticas (en index.html el logo enlaza a `/`, en contacto/legal enlaza a `index.html`; el footer de legal.html incluye además el badge de Google Play que en index.html aparece truncado en el rango de líneas comparado — revisar visualmente si hay duda, pero no es una diferencia de fondo).

**Implicación práctica:** cualquier cambio al hero, a la trust bar, a la fila de estadísticas, al nav o al footer debe replicarse en las tres páginas (index, contacto, legal) — así se ha trabajado hasta ahora (tareas #26, #83, #84, #85 del historial). Si pides un cambio en una sola, probablemente haya que preguntarte si también va en las otras dos.

---

## 2. Consistencia de datos entre páginas

No hay backend: todo el estado se guarda en `localStorage` del navegador, con estas claves:

- **`bp_calc`** — escrita por la calculadora de **index.html** (`weight`, `height`, `targetWeight`). Sirve solo para precargar el Paso 1 de intake.html.
- **`bp_profile`** — el objeto grande con todos los datos del paciente. Lo escribe **intake.html** (función `saveIntakeProfile()`, ~línea 1545) al terminar el registro, y lo lee/sobrescribe **portal.html** (`loadProfile()` / `saveProfileData()`, ~línea 2150) fusionándolo sobre un `DEFAULT_PROFILE` de demo (paciente ficticia "Valentina Morales") para que el portal nunca se vea vacío si no hay datos reales.
- **`bp_wlog`** — historial de registros de peso, usado y mantenido **solo dentro de portal.html** (no lo toca intake.html).

**Campos de `bp_profile` confirmados en ambos extremos** (intake escribe → portal lee): `nombre, apellido, email, celular, region, inscripcion, sexo, edad, fecha_nacimiento, estatura, peso_inicial, peso_actual, peso_objetivo, bmi, pa, fc, opioides, opioide_tipo, cirugia, cirugia_tipo, rx, medicamentos[], condiciones[], condiciones_ninguna, exclusiones[], exclusiones_ninguna, excluyentes, glp1, otros_meds, programas, _updates{}`.

**Nota verificada (no es un bug):** `DEFAULT_PROFILE` en portal.html tiene un campo `meds` (string, ej. `"Metformina, Espironolactona"`) que intake.html nunca escribe — intake solo llena `medicamentos` (array de objetos `{nombre, cantidad, frecuencia}`). Podría parecer una inconsistencia, pero en `portal.html` (~línea 2296-2316) hay lógica explícita, con un comentario propio en el código, que define la prioridad: 1) si el médico editó manualmente el campo desde el portal (`PROFILE._updates.meds`), ese texto libre manda; 2) si no, y existe `medicamentos[]` con elementos (el caso real, viene de intake), se renderiza ese arreglo estructurado; 3) solo si no hay nada de lo anterior se cae al string `meds` (que es lo que usa el perfil demo). Es decir, `meds` es exclusivamente el formato legado/demo y el mecanismo de override manual del médico — no una fuente de datos rota para pacientes reales.

**Los 3 tokens de color están duplicados con nombres distintos pero valores idénticos** entre archivos (ver sección 4) — no es una inconsistencia de datos de usuario, pero sí de mantenibilidad del código.

---

## 3. Flujo y arquitectura entre páginas

Mapa de navegación (con el dato que viaja en cada flecha):

```
index.html ──(bp_calc: weight, height, targetWeight)──▶ intake.html
                                                              │
                                              6 pasos numerados (1/6 a 6/6):
                                              s1 Perfil → s3 Historial médico →
                                              s4 Salud y antecedentes → s5 Signos
                                              vitales → s6 Proyección → s7 Últimas
                                              preguntas
                                              (nota: no existe div "s2"; la
                                              numeración interna de ids salta de
                                              s1 a s3, pero el contador visible
                                              sigue siendo correcto 1/6…6/6)
                                                              │
                                              → sResult (pantalla "Tu resultado",
                                                sin numerar) → sReg (pantalla
                                                "Inscripción", sin numerar)
                                                              │
                                              saveIntakeProfile() escribe bp_profile
                                                              │
                                                              ▼
                                                        portal.html
                                                  (loadProfile() lee bp_profile;
                                                   si no existe, usa el perfil
                                                   demo "Valentina Morales")

index.html / intake.html / portal.html ──"Volver al inicio"──▶ index.html
index.html ──nav "Portal Proveedores"──▶ proveedores.html (login con 3 tabs:
                                          Médicos / Farmacias / Staff — sin
                                          conexión real a backend, son inputs
                                          de demo)
index.html ──footer "Información Legal"──▶ legal.html
index.html ──footer "Contacto"──▶ contacto.html
contacto.html / legal.html / intake.html / portal.html / proveedores.html
   ──logo / "Volver al inicio"──▶ index.html
```

Páginas satélite (`contacto.html`, `legal.html`, `proveedores.html`) no participan del flujo de datos del paciente; son hojas terminales de navegación. `proveedores.html` es una pantalla de login de demostración (médicos/farmacias/staff) sin conexión a ningún sistema real — está ahí como placeholder de la futura red de proveedores médicos y farmacias (mencionados en el `PROMPT_MAESTRO` como mediclic, Care Assistance, Farmex).

Los `<title>` de cada página ya están diferenciados (tarea #77): index/contacto/legal/proveedores comparten `"Balance+ | Programa Médico"`, intake usa `"Balance+ | Evaluación del Paciente"`, portal usa `"Balance+ | Portal del Paciente"`.

---

## 4. Estilo visual: moderno y simple

**Paleta de marca** (idéntica en valor hexadecimal en todos los archivos, aunque con nombres de variable distintos):
- Navy `#1B2D5E` (primario), navy-dark `#142248`, navy-mid `#2a4080`
- Sage `#8AB090` (acento, "salud/progreso"), sage-dark `#6A9070`, sage-faint `#f0f6f1`
- Texto `#1a1f2e`, muted `#5a6475`, borde `#dde3e8`, fondo `#f7f9fb`, blanco `#ffffff`

index.html/contacto.html/legal.html usan `--navy/--sage/--bg` etc.; intake.html usa el mismo esquema más `--red/--amber` para validaciones; portal.html y proveedores.html usan en cambio `--primary/--accent` como nombres principales (con los mismos valores), y proveedores.html además declara alias `--navy/--sage/--white` para compatibilidad. **No es un bug** (cada archivo es standalone y funciona), pero si en algún momento se quiere consolidar a un único archivo de tokens compartido, hay que unificar nomenclatura.

**Patrón de layout fijo sin scroll en desktop** (index/contacto/legal): `html,body{height:100%;overflow:hidden}`, `.page{height:100vh}`, `main{display:grid;grid-template-columns:62fr 38fr;overflow:hidden}`. Cada columna (`.col-left`, `.col-right`) centra su contenido verticalmente de forma independiente (`justify-content:center`), lo que ha hecho que alinear elementos específicos entre columnas (p. ej. la fila de prensa con la fila de números) sea un ajuste empírico de `margin-top`, no un cálculo exacto — así se hizo con la sección "GLP-1 en Prensa" (terminó en `margin-top:44px` tras varias rondas de feedback). En mobile (`@media max-width:768px`) este patrón se desactiva y todo vuelve a fluir con scroll normal.

**Componente "pill" reutilizado:** el badge claro tipo "Tratamiento médico para bajar de peso" (fondo `var(--bg)` o `var(--white)` según el contenedor, borde 1px `var(--border)`, texto `var(--muted)` mayúsculas 11px) es el patrón estándar de etiqueta superior en todo el sitio — se reutilizó para "GLP-1 en Prensa". Importante: si se coloca un pill de este tipo dentro de `.col-right`, hay que usar `var(--white)` como fondo (no `var(--bg)`), porque `.col-right` ya tiene `var(--bg)` como fondo propio y el pill quedaría invisible.

**Tipografía:** Inter en todo el sitio, jerarquía con `h1` en `clamp(28px,3.2vw,44px)` para que el hero se adapte sin romper el layout fijo.

---

## 5. Propuesta de valor

Copy actual del hero (panel izquierdo, compartido en index/contacto/legal):

- **Badge superior:** "Tratamiento médico para bajar de peso"
- **H1:** "Peso saludable con respaldo *médico* y ciencia GLP-1"
- **Lead:** "Balance+ combina medicamentos de última generación con seguimiento médico personalizado para que pierdas peso de forma segura y con resultados sostenibles."
- **Checklist (4 puntos):** seguimiento personalizado por un médico · medicamentos recetados por un médico · recibe el medicamento en tu hogar · haz tus reembolsos en Isapre, FONASA y seguros.
- **CTA principal:** "Ver si soy candidato" → lleva a intake.html.
- **Estadísticas clínicas (fila de 3 números):** -18% reducción promedio del peso corporal · 6x más efectivo que sólo dieta y ejercicio · 93% de pacientes satisfechos con sus resultados.

En el panel derecho de index.html, la calculadora ("¡Súbete a nuestra balanza!") deja entrar peso/estatura y devuelve una proyección Hoy / Con Balance+ / Podrías perder (rango en kg), con la nota "Estimación basada en los resultados promedio del tratamiento con semaglutida en 12 meses. Los resultados individuales pueden variar según cada paciente." — es el gancho principal de conversión antes de pasar a intake.html.

La sección "GLP-1 en Prensa" (2 noticias: La Tercera sobre Wegovy, T13 sobre "Selfix, el nuevo Ozempic chileno" con badge "PRONTO") funciona como prueba social / validación de la categoría GLP-1 en medios chilenos, reforzando que el tratamiento no es experimental sino una tendencia ya cubierta por prensa nacional.

El posicionamiento general (según `PROMPT_MAESTRO_BalancePlus.md`) es de **orquestador tecnológico** al estilo Ro/Hims/Medvi: Balance+ articula médicos (proveedores médicos por confirmar), farmacias aliadas (por confirmar) y pacientes, sin atención presencial, con entrega de medicamento a domicilio.

---

## 6. Información legal y cómo avanzamos

**Arquitectura validada: 9 documentos**, generados a partir de `PROMPT_MAESTRO_BalancePlus.md` (que a su vez nace del informe de investigación `compass_artifact_wf-935e4373...md`, verificado contra el Diario Oficial). Los documentos:

| # | Documento | ¿Visible al usuario en legal.html? |
|---|---|---|
| 01 | Términos y Condiciones de Uso | Sí |
| 02 | Política de Privacidad | Sí |
| 03 | Aviso de Tratamiento de Datos (Ley 21.719) | Sí |
| 04 | Procedimiento ARCOP | Sí |
| 05 | Política de Cookies | Sí |
| 06a | Consentimiento Informado de Telemedicina | Sí |
| 06b | Consentimiento de Datos de Salud | Sí |
| 06c | Consentimiento informado GLP-1 | Sí |
| 07 | DPA / Acuerdo de Tratamiento de Datos con encargados | No — documento interno, solo para contratos con proveedores |
| 08 | Política de Seguridad de la Información | No — interno |
| 09 | Aviso de Privacidad resumido in-app | No — interno, para insertarse como capa corta dentro del flujo (registro, consulta, perfil), no como documento descargable |

**Marco legal de referencia:** Ley 21.719 (reforma a la Ley 19.628, vigente desde el 1-dic-2026 — datos sensibles, ARCOP en 30 días corridos, deber de información, brechas "sin dilaciones indebidas" — **importante: NO existen las "72 horas" en la ley chilena, eso es del GDPR**, ya corregido en el prompt maestro), Ley 20.584 (consentimiento informado, ficha clínica 15 años), Ley 21.541 + Decreto 6/2021 + NGT 237 (telemedicina), Código Sanitario + DS 11/2025 + SNRE (receta electrónica con Clave Única), Ley 19.496/LPDC (retracto 10 días, con exclusión para servicios de salud ya prestados).

**Estado real — pendiente antes de publicar (de `AUDITORIA_Documentos_Publicos_BalancePlus.docx`, no resuelto todavía):**
1. **Crítico:** todos los documentos públicos (01–06c) incluyen actualmente la nota "Documento de insumo; debe ser revisado por un abogado/DPO chileno antes de su publicación" generada por la función `buildDoc()`. Esa nota es apropiada para uso interno pero **no debe aparecer en lo que firma el paciente** — debilita la validez del consentimiento. Corrección propuesta: separar `buildDocPublic()` (sin esa nota) de `buildDocInternal()` (con ambas notas, para 07–09).
2. **Crítico:** el Documento 03 contiene literalmente el placeholder de trabajo `[VERIFICAR ARTÍCULO APLICABLE EN TEXTO FINAL DE LA LEY]` en la sección de EIPD — hay que completarlo o quitar la sección hasta tenerlo.
3. **Menor:** expandir "p. ej." a "por ejemplo" en docs 03 y 04.
4. **Pendiente de completar:** Documento 05 (Cookies) tiene placeholders propios `[PROVEEDORES ANALÍTICOS]` y `[PROVEEDORES DE MARKETING]` que no son parte del set estándar de placeholders del proyecto.
5. **Revisión médica pendiente:** el contenido clínico del Documento 06c (efectos adversos, contraindicaciones, dosis) debe ser validado por un médico, no solo por un abogado.
6. **Ajuste de redacción sugerido:** el ítem 2 de la sección 9 del Documento 06c asume una conversación previa con el médico que puede no haber ocurrido en un flujo 100% digital — hay una propuesta de texto alternativo en la auditoría.
7. Placeholders estándar del proyecto (`[RAZÓN SOCIAL]`, `[RUT]`, `[DOMICILIO LEGAL]`, `[CORREO DE CONTACTO]`, `[DATOS DEL DPO/DELEGADO]`, `[PROVEEDORES MÉDICOS]`, `[FARMACIAS ALIADAS]`) siguen sin rellenar en todos los documentos — a la espera de que el usuario confirme razón social/RUT real y los nombres reales de proveedores médicos y farmacias aliadas.

**Cómo avanzamos (siguientes pasos lógicos, no decididos aún — confirmar con el usuario antes de ejecutar):** aplicar la corrección #1 (separar nota pública/interna) a los 8 documentos públicos; resolver el placeholder de EIPD en el doc 03; completar los placeholders de proveedores analíticos/marketing en el doc 05; y, cuando el usuario tenga los datos reales (razón social, RUT, proveedores médicos y farmacias confirmadas), reemplazar todos los placeholders estándar. Ninguno de estos documentos debe considerarse listo para publicación sin revisión de abogado/DPO chileno real — eso es una advertencia explícita del propio set de documentos, no una opinión de esta sesión.

---

## Inventario de archivos (referencia rápida)

- **Páginas:** `index.html`, `contacto.html`, `legal.html`, `intake.html`, `portal.html`, `proveedores.html`
- **Documentos legales:** `01_Terminos_y_Condiciones_BalancePlus` … `06c_Consentimiento_GLP1_BalancePlus` (docx+pdf), `07_DPA_...`, `08_Politica_Seguridad_...`, `09_Aviso_Resumido_InApp_...` (solo docx), `AUDITORIA_Documentos_Publicos_BalancePlus.docx`
- **Prompts/investigación:** `PROMPT_MAESTRO_BalancePlus.md` (prompt para generar/regenerar los 9 documentos legales), `compass_artifact_wf-935e4373-308c-4301-9d64-4ddca688337d_text_markdown.md` (informe de investigación legal que originó el prompt maestro)
- **Imágenes clave:** `hero_collage.png` (+ variantes de respaldo de iteraciones anteriores — no usar las variantes, solo la actual), logos de prensa (`latercera-square.png`, `t13-square.png`), íconos de trust bar (`icono-identidad.png`, `icono-medicos.png`, `icono-farmacias.png`, `icono-balanza-peso.png`), badges de tiendas de apps, `Isotipo 2.png` (favicon de todas las páginas)

Si en la nueva conversación el usuario comparte la carpeta completa, vale la pena re-listar el directorio (`ls -la`) para detectar archivos nuevos que no estén descritos aquí, y volver a leer los archivos HTML completos antes de tocar nada — este brief acelera la orientación, no sustituye la lectura.
