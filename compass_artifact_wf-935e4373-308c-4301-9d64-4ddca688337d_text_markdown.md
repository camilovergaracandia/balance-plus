# Informe: Dossier de Fuentes, Marco Regulatorio, Arquitectura Documental y PROMPT MAESTRO para "Balance+" (Balance Plus)

## TL;DR
- **Los 6 documentos que el usuario validó son correctos pero insuficientes**: se recomienda ampliar a **9 documentos**, sumando un Acuerdo de Tratamiento de Datos (DPA) con encargados, una Política de Seguridad de la Información y un Aviso de Privacidad resumido in-app, dado el modelo de orquestación con terceros y el tratamiento masivo de datos sensibles de salud.
- **El marco aplicable fue verificado contra el texto oficial del Diario Oficial (13-dic-2024)**: datos sensibles (art. 2 g), salud/perfil biológico (art. 16 bis), consentimiento de sensibles (art. 16), ARCOP en 30 días corridos (art. 11), deber de información (art. 14 ter), brechas (art. 14 **sexies** — sin plazo en horas en la ley chilena), DPO voluntario (art. 50), multas hasta 20.000 UTM (art. 35) y vigencia el 1-dic-2026. **Corrección crítica**: la "regla de 72 horas" NO existe en la ley chilena; proviene del art. 33(1) del GDPR europeo.
- **Las 19 fuentes fueron rastreadas**; las más aprovechables son la Política de Privacidad y el flujo ARCO+P de Clínica Alemana y los 6 PDFs descargables de Clínica Santa María (T&C Sitio Web, T&C App/Portal, T&C Telemedicina, Política de Privacidad Sitio Web, Política de Privacidad App/Portal y Política de Cookies, versiones 2025).

---

## Key Findings

### Sobre el marco regulatorio
1. **La Ley 21.719 NO crea un cuerpo legal nuevo**: reforma la Ley 19.628 (que pasa a llamarse "sobre protección de los datos personales"). La UI actual de Balance+ que cita la 19.628 no está "errada", pero está desactualizada: debe redactarse bajo el articulado reformado, vigente desde el 1-dic-2026.
2. **Dato de salud = dato sensible con régimen reforzado**: requiere consentimiento expreso (art. 16) y solo puede tratarse para fines de leyes sanitarias (art. 16 bis). Balance+ los trata a gran escala, lo que gatilla además **Evaluación de Impacto en Protección de Datos (EIPD) obligatoria**.
3. **No existe un plazo de "72 horas" en la ley chilena** para notificar brechas: el texto (art. 14 sexies) solo dice "por los medios más expeditos posibles y sin dilaciones indebidas". Las 72 horas son una práctica de mercado importada del **art. 33(1) del GDPR**, cuyo texto literal es: *"the controller shall without undue delay and, where feasible, not later than 72 hours after having become aware of it, notify the personal data breach to the supervisory authority"*. Esto debe corregirse en todo documento de Balance+.
4. **El modelo de orquestación es jurídicamente delicado**: Balance+ debe definir si actúa como responsable, corresponsable o encargado frente a médicos y farmacias, y suscribir DPAs. La tercerización NO exime de responsabilidad (Ley 21.541).
5. **Receta electrónica modernizada**: el DS N°11/2025 (vigente 2-dic-2025) y el SNRE (lanzado el **10-dic-2025 en la farmacia La Torre, Santiago, por la ministra (s) de Salud Andrea Albagli y el presidente del Colegio Químico Farmacéutico Héctor Torres**) permiten recetas con Clave Única, pero la prescripción sigue exigiendo evaluación previa del paciente (art. 101 Código Sanitario).
6. **Semaglutida y pérdida de peso en Chile**: el ISP, en su comunicado oficial ("ISP informa sobre semaglutida"), señala que *"El medicamento original Ozempic consiste en semaglutida de origen biológico, para el tratamiento de la diabetes tipo 2 y obesidad"*; sin embargo, la indicación registrada en Chile de Ozempic ha sido para diabetes tipo 2, y **Wegovy (semaglutida 2,4 mg) está en proceso de registro para obesidad**. Por tanto, el uso de semaglutida con fines de pérdida de peso debe tratarse con cautela y transparencia (riesgo de uso off-label según producto/indicación). **Recomiendo confirmar con el ISP el estado de registro vigente de cada producto al momento de redactar.**

### Sobre las fuentes
7. La fuente de mayor valor de referencia es **Clínica Alemana**, que ya opera bajo el concepto "ARCO+P" e incluso tiene un **formulario web de ejercicio de derechos** (`/telemedicina/solicitud-arcop`).
8. **Clínica Santa María** ofrece la arquitectura documental más cercana al modelo Balance+ (separa T&C Sitio Web, T&C App y Portal, T&C Telemedicina, Política de Privacidad Sitio Web, Política de Privacidad App y Portal, y Política de Cookies — todos descargables en PDF).

---

## Details

### TAREA 1 — DOSSIER DE FUENTES INDEXADO

**A) Clínica Santa María**
- `https://www.clinicasantamaria.cl/consentimientos` — Página "Consentimientos" (Privacidad y Seguridad). Carga contenido dinámicamente (JS); no expone PDFs en el HTML estático. Útil como referencia de UX de consentimientos. *(Revisar manualmente en navegador.)*
- `https://www.clinicasantamaria.cl/informacion-general/terminos-y-condiciones` — Página índice de T&C. **Contiene 6 descargables PDF de alto valor** (utilidad: documentos 1, 2, 5, 6 de Balance+):
  - Política de cookies: `https://drprod-gphdeze8e5bnfegs.a03.azurefd.net/sites/default/files/2025-06/Politica%20de%20Cookies.pdf`
  - Política de Privacidad Sitio Web: `https://drprod-gphdeze8e5bnfegs.a03.azurefd.net/sites/default/files/2025-06/Politica%20de%20Privacidad%20Sitio%20Web.pdf`
  - Política de Privacidad APP y Portal: `https://drprod-gphdeze8e5bnfegs.a03.azurefd.net/sites/default/files/2025-11/CSM%20-%20Pol%C3%ADtica%20de%20Privacidad%20APP%20y%20Portal.pdf`
  - Términos y Condiciones APP y Portal: `https://drprod-gphdeze8e5bnfegs.a03.azurefd.net/sites/default/files/2025-11/SANTA%20MAR%C3%8DA%20-%20T%C3%A9rminos%20y%20Condiciones%20App%20y%20Portal%20AGO%202025%20%281%29.pdf`
  - Términos y Condiciones Telemedicina: `https://drprod-gphdeze8e5bnfegs.a03.azurefd.net/sites/default/files/2025-11/SANTA%20MAR%C3%8DA%20-%20T%C3%A9rminos%20y%20Condiciones%20Telemedicina.pdf`
  - Términos y Condiciones Sitio Web: `https://drprod-gphdeze8e5bnfegs.a03.azurefd.net/sites/default/files/2025-11/SANTA%20MAR%C3%8DA%20-%20T%C3%A9rminos%20y%20Condiciones%20Sitio%20Web.pdf`
- PDFs corporativos provistos por el usuario (Código de Conducta `…/2025-05/c%C3%B3digo-de-conducta_0.pdf`; Manual Código de Conducta Terceras Partes `…/2025-05/sm---manual-codigo-conducta-terceras-partes_0.pdf`; Manual Modelo de Prevención `…/2025-05/manual-modelo-prevenci%C3%B3n_0.pdf`): son de compliance corporativo. Útiles solo como referencia para una eventual Política de Compliance/Modelo de Prevención (art. 49 Ley 21.719), NO para los documentos de cara al usuario.
- `https://www.clinicasantamaria.cl/informacion-general/centro-de-ayuda-etica-y-cumplimiento` — Centro de ayuda ética/cumplimiento; referencia para canal de denuncias.

**B) Care Assistance** (proveedor aliado del usuario — relevante porque es uno de los terceros)
- `https://www.careassistance.com/politicas-de-privacidad` — Política de Privacidad. Estructura aprovechable: definiciones, principios (licitud, finalidad, proporcionalidad, seguridad, transparencia, confidencialidad, temporalidad), autorización, datos recolectados, encargados, derechos. **Domicilio declarado: Nueva de Lyon 72, of. 702, piso 7, Providencia.** Aún redactada bajo "normas que regulan la protección de la vida privada" (19.628).
- `https://www.careassistance.com/politicas-de-cookies` — Política de Cookies. Estructura modelo: qué son, para qué se usan, tipos (sesión, persistentes, propias, terceros), gestión.
- `https://www.careassistance.com/politicas-de-calidad` — Política de Calidad (no fetcheada en detalle). En el footer del sitio se exhiben certificaciones **ISO 27001 e ISO 9001**, útiles como referencia para la Política de Seguridad de la Información.

**C) INDISA**
- `https://www.indisa.cl/informacion-legal/informacion-importante` — Información legal corporativa (estatutos refundidos, EEFF, operaciones con partes relacionadas, gobierno corporativo). Poco útil para documentos de usuario; sí para gobierno corporativo.
- `https://ng-backend.indisa.cl/app/uploads/2020/12/terminos-condiciones-web-indisa.pdf` (enlazado también desde `https://ng-backend.indisa.cl/terminos-condiciones-web-indisa`) — T&C web. Referencia básica.
- `https://www.indisa.cl/legal/canal-de-denuncias`, `https://www.indisa.cl/informacion-legal/prevencion-de-delitos`, `https://www.indisa.cl/legal/practicas-gobierno-corporativo` — referencia para compliance/canal de denuncias.

**D) Clínica Alemana** (la fuente más valiosa)
- `https://www.clinicaalemana.cl/privacidad-y-terminos/politica-de-privacidad` — Política de Privacidad completa. **Estructura modelo** (utilidad: documentos 2 y 3): definiciones, normas aplicables (Código Sanitario; Ley 19.628; Ley 20.584; Reglamento de Ficha Clínica Decreto N°41/2012; Decreto N°6/2021 telemedicina), principios, confidencialidad, datos recolectados y finalidad, almacenamiento, cookies/analítica, entrega a terceros, temporalidad (ficha clínica 15 años), derechos ARCO+P, responsabilidades del usuario, seguridad, jurisdicción.
- `https://www.clinicaalemana.cl/telemedicina/solicitud-arcop` — **Formulario de ejercicio de derechos ARCO+P** (modelo directo para el Documento 4 de Balance+).
- `https://www.clinicaalemana.cl/privacidad-y-terminos/alemana` y subpáginas (`…/telemedicina-de-cllinica-alemana`, `…/alemana-go-app-web`, `…/reserva-de-hora`) — confirman el patrón de desdoblar T&C por servicio.
- `https://www.clinicaalemana.cl/reglamento-interno-de-funcionamiento` y el PDF `_reglamento_interno_de_funcionamiento.pdf` (CloudFront) — referencia para reglamento interno.
- `https://centrodeayuda.clinicaalemana.cl/terminos_legales/Leyes_y_normativas` — listado de normativa aplicable.

### TAREA 2 — MARCO REGULATORIO (verificado contra fuente oficial: Diario Oficial N°44.023, 13-dic-2024)

**a) Protección de datos — Ley 21.719 (reforma a la Ley 19.628)**
- Publicada en el Diario Oficial el **13-dic-2024**; vigencia **1-dic-2026** (Artículo primero transitorio: "el día primero del mes vigésimo cuarto posterior a la publicación").
- **Definición de datos sensibles: art. 2 letra g)** — incluye salud, perfil biológico humano, datos biométricos, vida/orientación sexual e identidad de género.
- **Bases de licitud: art. 12** (consentimiento, regla general — libre, específico, informado e inequívoco, revocable) y **art. 13** (otras fuentes sin consentimiento: obligación legal; contrato/medidas precontractuales; interés legítimo; ejercicio de derechos ante tribunales; datos económicos del Título III).
- **Consentimiento de datos sensibles: art. 16** — consentimiento expreso por declaración escrita, verbal o medio tecnológico equivalente, con excepciones tasadas.
- **Salud y perfil biológico: art. 16 bis** — solo para fines de leyes sanitarias; excepciones tasadas (salvaguarda de vida/integridad, alerta sanitaria, fines científicos/estadísticos o desarrollo de productos médicos, defensa de derechos, medicina preventiva/laboral, mandato legal).
- **Deber de información/transparencia: art. 14 ter** — 12 contenidos mínimos de la política (identificación del responsable, finalidades, categorías de datos, base de licitud, destinatarios, transferencias internacionales, plazos de conservación, derechos, retiro del consentimiento, decisiones automatizadas, etc.).
- **Deber de adoptar medidas de seguridad: art. 14 quinquies** (confidencialidad, integridad, disponibilidad y resiliencia).
- **Deber de reportar brechas: art. 14 sexies** — se reporta a la Agencia "sin dilaciones indebidas" (NO hay plazo en horas en la ley); además a los titulares cuando se afecten datos sensibles, de menores de 14 años o económicos.
- **ARCOP + portabilidad y bloqueo**: derechos en arts. 5–9; procedimiento y **plazo de respuesta de 30 días corridos, prorrogable una vez por 30 días corridos** en el **art. 11**; bloqueo temporal en 2 días hábiles.
- **Encargado del tratamiento (DPA)**: el tratamiento por encargado se rige por contrato que debe fijar objeto, duración, finalidad, tipo de datos, categorías de titulares y obligaciones; la subdelegación requiere autorización específica y por escrito, con **responsabilidad solidaria**; el encargado debe cumplir los arts. 14 bis y 14 quinquies.
- **DPO: art. 50** — facultativo con carácter general ("podrá designar"); obligatorio como elemento del **Modelo de Prevención de Infracciones (art. 49)** cuando éste se adopta voluntariamente.
- **Agencia de Protección de Datos Personales: art. 30** (corporación autónoma de derecho público, vinculada al Ministerio de Economía).
- **Transferencias internacionales: arts. 27 y 28** (decisión de adecuación, cláusulas contractuales, normas corporativas vinculantes, modelos de certificación).
- **Régimen sancionatorio**: clasificación en arts. 34/34 bis/34 ter/34 quáter; multas en el **art. 35** — leves hasta **5.000 UTM**, graves hasta **10.000 UTM**, gravísimas hasta **20.000 UTM** (≈ USD 1,55 millón al valor UTM de febrero 2026). En **reincidencia dentro de 5 años**, para empresas que no son de menor tamaño, se aplica el mayor entre la multa triplicada o **2% (grave) / 4% (gravísima) de los ingresos anuales** por ventas y servicios en Chile.
- **Régimen transitorio PYME: Artículo sexto transitorio** — durante los primeros **12 meses** desde la vigencia, la Agencia podrá aplicar amonestación escrita en lugar de multa a empresas de menor tamaño (art. 2 de la Ley 20.416).

**b) Salud y telemedicina**
- **Ley 20.584** (derechos y deberes del paciente): consentimiento informado (**art. 14**); confidencialidad de la ficha clínica (toda su información es dato sensible); derecho a la información (arts. 9–11). El **Reglamento de Ficha Clínica (Decreto N°41/2012 MINSAL, promulgado 24-jul-2012, publicado 15-dic-2012), art. 12**, exige conservar las fichas *"durante el plazo mínimo de 15 años"*; fiscaliza la Superintendencia de Salud (Intendencia de Prestadores).
- **Ley 21.541** (publicada 17-mar-2023): autoriza telemedicina; modifica los arts. 1, 3, 8, 8 bis, 9, 10 bis, 11, 13 y 14 de la Ley 20.584 y los arts. 120 y 122 del Código Sanitario; los prestadores son responsables del registro y de los estándares de seguridad — **la tercerización no exime de responsabilidad**.
- **Decreto N°6/2021 MINSAL** (publicado 9-dic-2022): Reglamento sobre acciones vinculadas a la atención de salud realizada a distancia.
- **Norma General Técnica N°237** (Decreto exento N°51, 18-oct-2024): estándares técnicos, de seguridad de la información y de consentimiento para telemedicina (incluye deber de información y obtención del consentimiento).
- **Ley 21.668** (23-may-2024): interoperabilidad de la ficha clínica.
- **Decreto N°31/2012 MINSAL**: Reglamento sobre entrega de información y expresión de consentimiento informado.

**c) Receta y medicamentos**
- **Código Sanitario**: art. 100 (venta bajo receta) y art. 101 (receta como instrumento privado, evaluación previa del paciente, receta gráfica o electrónica).
- **DS N°11/2025** (publicado 20-may-2025; vigente 2-dic-2025): modifica el Reglamento de Farmacias (DS 466/1984) para permitir receta electrónica validada con **Clave Única**, eliminando la exigencia de Firma Electrónica Avanzada para recetas estándar.
- **SNRE** (Sistema Nacional de Receta Electrónica): lanzado por MINSAL el **10-dic-2025**; plataforma pública y gratuita, recetas accesibles vía Clave Única en `recetaelectronica.minsal.cl`.
- **ISP**: Ozempic (semaglutida) registro **B-2774**; venta bajo receta retenida; alerta del ISP sobre uso indebido para baja de peso. Confirmar estado de registro vigente por producto (Ozempic, Wegovy, Saxenda, Victoza, Rybelsus, Mounjaro/tirzepatida, Zepbound).

**d) Consumidor / e-commerce**
- **Ley 19.496 (LPDC)**: deberes de información (arts. 1, 3); **derecho a retracto en contratos a distancia (art. 3 bis): 10 días desde la recepción/contratación**, antes de la prestación; obligación de confirmación escrita del contrato (sin ella, el retracto se extiende); Reglamento de Comercio Electrónico (vigente 24-mar-2022). El derecho a retracto puede excluirse expresa y anticipadamente por el proveedor — relevante para servicios de salud ya prestados.

**e) Cookies**: no hay ley específica de cookies en Chile; el consentimiento se rige por las bases de licitud de la Ley 21.719 (consentimiento para cookies no esenciales), con mejores prácticas alineadas a GDPR/ePrivacy (banner con aceptar/rechazar/configurar, registro/trazabilidad del consentimiento).

**f) Relación con terceros**: necesidad de **DPAs** con médicos (mediclic, Care Assistance) y farmacias (Farmex), definiendo el reparto de roles responsable/encargado/corresponsable.

**g) Reembolsos Isapre/FONASA/seguros**: compartir datos con aseguradores requiere base de licitud (ejecución de contrato y/o consentimiento específico para esa comunicación); operadores como i-Med procesan bonos.

### TAREA 3 — ARQUITECTURA FINAL DE DOCUMENTOS (9 documentos)

Se valida la arquitectura de 6 y se recomienda **ampliar a 9**:

1. **Términos y Condiciones de Uso** (web y app). Fundamento: Ley 19.496; Código Civil; Código de Comercio (formación del consentimiento). Modelo: T&C App/Portal de Santa María; T&C de Clínica Alemana.
2. **Política de Privacidad** (general). Fundamento: art. 14 ter Ley 21.719. Modelo: Política de Privacidad de Clínica Alemana y de Santa María (App/Portal).
3. **Política/Aviso de Tratamiento de Datos Personales conforme a Ley 21.719**. Fundamento: arts. 12, 13, 14, 14 ter, 16, 16 bis. Modelo: la política de Alemana actualizada al nuevo estándar.
4. **Procedimiento de Ejercicio de Derechos ARCOP**. Fundamento: arts. 5–9 y 11 (plazo 30 días corridos). Modelo: formulario ARCO+P de Clínica Alemana.
5. **Política de Cookies**. Fundamento: Ley 21.719 + GDPR/ePrivacy. Modelo: Política de Cookies de Care Assistance y de Santa María.
6. **Consentimiento(s) Informado(s)** — desdoblado en: (6a) **Consentimiento Informado de Telemedicina** (Ley 20.584 art. 14; Ley 21.541; Decreto 6/2021; NGT 237); (6b) **Consentimiento específico para tratamiento de datos de salud** (arts. 16 y 16 bis Ley 21.719); (6c) **Consentimiento informado del tratamiento GLP-1** (indicación, carácter off-label según producto, riesgos/efectos adversos, contraindicaciones, criterios de exclusión).
7. **(NUEVO) Acuerdo de Tratamiento de Datos / DPA** con encargados (médicos, farmacias, proveedores TI). Fundamento: régimen del encargado Ley 21.719.
8. **(NUEVO) Política de Seguridad de la Información**. Fundamento: art. 14 quinquies + NGT 237 + Ley 21.663 (Marco de Ciberseguridad).
9. **(NUEVO) Aviso de Privacidad resumido in-app / capa corta**. Fundamento: principio de transparencia (art. 14 ter), entregado en el momento de la recolección (intake de 6 pasos).

### TAREA 4(d) — PROMPT MAESTRO (listo para Claude Cowork)

```
PROMPT MAESTRO — GENERACIÓN DE DOCUMENTOS LEGALES PARA "BALANCE+" (BALANCE PLUS)

ROL: Actúa como abogado/a chileno/a senior especializado/a en protección de datos personales, derecho sanitario y derecho del consumidor, con experiencia en plataformas de salud digital. Redactarás un conjunto de documentos legales para la plataforma de telemedicina "Balance+".

CONTEXTO DEL NEGOCIO:
- "Balance+" (Balance Plus) es un emprendimiento personal e independiente de Gabriel [APELLIDOS], SIN relación alguna con MetLife Chile (no usar su identidad legal ni asociarla).
- Domicilio comercial: Laura de Noves 320, Las Condes, Santiago, Chile.
- Plataforma web y app de telemedicina para PÉRDIDA DE PESO mediante medicamentos GLP-1 (semaglutida: Ozempic, Wegovy, Saxenda, Victoza, Rybelsus; tirzepatida: Mounjaro, Zepbound).
- Modelo de ORQUESTACIÓN (tipo Ro/Hims/Medvi): Balance+ articula entre médicos (proveedores: mediclic, Care Assistance), farmacias (Farmex y otras) y pacientes. NO hay atención presencial; entrega de medicamento a domicilio. Posicionamiento como intermediario tecnológico/orquestador, no como prestador directo de salud — pero ADVIERTE que esta calificación debe confirmarse con abogado, pues la tercerización NO exime de responsabilidad (Ley 21.541).
- Trata DATOS SENSIBLES DE SALUD a gran escala: peso/IMC, sexo biológico, fecha de nacimiento, condiciones médicas (incl. enfermedad renal/hepática terminal, ideación/intento suicida, cáncer activo, dependencia de sustancias, diabetes, hipertensión, SOP, VIH), medicamentos actuales, signos vitales, cirugía bariátrica, uso de opioides.
- Solo mayores de 18 años (excluye menores).
- Funcionalidades: intake médico en 6 pasos, portal del paciente, videollamada de telemedicina, seguimiento de medicación/dosificación, registro de peso, perfil médico editable con notificación al médico. Login social (Google, Facebook/Instagram, Apple) y email/contraseña. Reembolsos Isapre/FONASA/seguros. Flujo de pagos.

INSTRUCCIONES DE REDACCIÓN:
- Idioma: español jurídico chileno; registro formal pero claro y comprensible para el paciente.
- Redacta bajo el estándar de la LEY 21.719 (que reforma la Ley 19.628), NO bajo la antigua Ley 19.628. Usa la nomenclatura y artículos vigentes desde el 1-dic-2026.
- Tratamiento REFORZADO de datos sensibles de salud (consentimiento expreso, arts. 16 y 16 bis).
- DEJA SIEMPRE como PLACEHOLDERS entre corchetes (NO los rellenes; se completan manualmente al final): [RAZÓN SOCIAL], [RUT], [DOMICILIO LEGAL] (referencia: Laura de Noves 320, Las Condes), [CORREO DE CONTACTO], [DATOS DEL DPO/DELEGADO], [NOMBRE COMERCIAL DE PROVEEDORES MÉDICOS: mediclic, Care Assistance], [FARMACIAS ALIADAS: Farmex y otras].
- Cita únicamente normas REALES y verificables; si no tienes certeza de un número de artículo, indícalo con "[verificar artículo]" en lugar de inventar.
- NO afirmes que existe un plazo legal de 72 horas para notificar brechas en Chile: la ley (art. 14 sexies) dice "sin dilaciones indebidas". Las 72 horas son del GDPR (art. 33), no de la ley chilena.
- Cada documento debe terminar con: "Documento de insumo; debe ser revisado por un abogado/DPO chileno antes de su publicación."
- Incluye fecha de versión y mecanismo de actualización.

MARCO NORMATIVO A INVOCAR (verificado contra el Diario Oficial):
- Ley 21.719 / Ley 19.628 reformada: art. 2 g) (datos sensibles), art. 11 (ARCOP, 30 días corridos), arts. 12-13 (bases de licitud), art. 14 ter (deber de información), art. 14 quinquies (seguridad), art. 14 sexies (brechas, "sin dilaciones indebidas"), art. 16 (consentimiento sensibles), art. 16 bis (salud/perfil biológico), arts. 27-28 (transferencias internacionales), art. 30 (Agencia), arts. 34-35 (sanciones, hasta 20.000 UTM), arts. 49-50 (modelo de prevención y DPO).
- Ley 20.584 (derechos y deberes del paciente): consentimiento informado (art. 14), confidencialidad de la ficha clínica; Decreto 41/2012 art. 12 (conservación 15 años).
- Ley 21.541 + Decreto 6/2021 MINSAL + Norma General Técnica N°237: telemedicina.
- Código Sanitario arts. 100-101; DS N°11/2025 y SNRE (receta electrónica con Clave Única).
- ISP: confirmar registro/indicación vigente de cada producto GLP-1; advertir sobre uso off-label para pérdida de peso; venta bajo receta retenida.
- Ley 19.496 (LPDC): derecho a retracto (art. 3 bis, 10 días), deberes de información, Reglamento de Comercio Electrónico.

DOCUMENTOS A GENERAR (genera cada uno con su índice de secciones):

[Documento 1 — Términos y Condiciones de Uso]
1. Identificación del titular y domicilio. 2. Objeto y descripción del servicio (rol de orquestador). 3. Requisito de mayoría de edad (18+). 4. Registro y cuenta (login social y email). 5. Flujo: intake 6 pasos, teleconsulta, prescripción, dispensación y entrega a domicilio. 6. Rol y responsabilidad de médicos y farmacias terceros; deslinde de responsabilidad del orquestador (con advertencia). 7. Precios, pagos y reembolsos (Isapre/FONASA/seguros). 8. Derecho a retracto (art. 3 bis LPDC) y sus exclusiones para servicios de salud ya prestados. 9. Obligaciones del usuario (veracidad de datos). 10. Propiedad intelectual. 11. Limitación de responsabilidad. 12. Modificaciones. 13. Ley aplicable y jurisdicción (Chile). 14. Contacto.

[Documento 2 — Política de Privacidad]
1. Identificación del responsable y DPO. 2. Definiciones. 3. Principios (art. 3). 4. Datos recolectados (incl. categorías sensibles de salud). 5. Finalidades y bases de licitud por finalidad (arts. 12-13, 16, 16 bis). 6. Login social. 7. Destinatarios y encargados (médicos, farmacias, TI, aseguradores). 8. Transferencias internacionales (arts. 27-28). 9. Plazos de conservación (ficha clínica 15 años). 10. Medidas de seguridad (art. 14 quinquies). 11. Derechos ARCOP y cómo ejercerlos (art. 11). 12. Notificación de brechas (art. 14 sexies). 13. Cookies (reenvío). 14. Actualizaciones. 15. Contacto y reclamo ante la Agencia.

[Documento 3 — Política/Aviso de Tratamiento de Datos Personales conforme a Ley 21.719]
Versión exhaustiva del deber de información del art. 14 ter con los 12 contenidos mínimos, énfasis en datos de salud (art. 16 bis), decisiones automatizadas/perfilamiento si aplica, y EIPD.

[Documento 4 — Procedimiento de Ejercicio de Derechos ARCOP]
1. Derechos cubiertos (acceso, rectificación, cancelación/supresión, oposición, portabilidad, bloqueo). 2. Canal y formulario. 3. Acreditación de identidad. 4. Plazos (30 días corridos, prórroga; bloqueo 2 días hábiles). 5. Excepciones (ficha clínica/conservación legal). 6. Recurso ante la Agencia. (Modelo: formulario ARCO+P Clínica Alemana.)

[Documento 5 — Política de Cookies]
1. Qué son. 2. Tipos (sesión, persistentes, propias, terceros). 3. Finalidades (técnicas, personalización, analítica, marketing). 4. Base de licitud y consentimiento. 5. Gestión y revocación. 6. Cookies de terceros (login social, analítica). 7. Actualizaciones.

[Documento 6 — Consentimientos Informados]
6a. Consentimiento Informado de Telemedicina (Ley 20.584 art. 14, Ley 21.541, Decreto 6/2021, NGT 237): naturaleza de la teleconsulta, limitaciones, condiciones tecnológicas, registro en ficha clínica, derecho a atención presencial alternativa.
6b. Consentimiento específico para tratamiento de datos de salud (arts. 16/16 bis).
6c. Consentimiento informado del tratamiento GLP-1: indicación, carácter off-label para pérdida de peso (según producto), riesgos/efectos adversos (pancreatitis, etc.), contraindicaciones, criterios de exclusión, deber de informar condiciones médicas.

[Documento 7 — DPA / Acuerdo de Tratamiento de Datos con encargados]
Objeto, duración, finalidad, tipos de datos, categorías de titulares, instrucciones documentadas, confidencialidad, seguridad, subencargados (autorización previa, responsabilidad solidaria), asistencia en derechos ARCOP y brechas, devolución/supresión al término, auditoría.

[Documento 8 — Política de Seguridad de la Información]
Alineada al art. 14 quinquies, NGT 237 y Ley 21.663: control de acceso, cifrado, registros/logs, gestión de incidentes y brechas, respaldos.

[Documento 9 — Aviso de Privacidad resumido in-app]
Capa corta entregada en el intake de 6 pasos, con enlace a la política completa y al consentimiento de datos de salud.
```

---

## Recommendations
1. **Adoptar la arquitectura de 9 documentos** y usar el PROMPT MAESTRO para generar borradores, sometiéndolos luego a revisión de abogado/DPO chileno antes del lanzamiento.
2. **Definir tempranamente el rol jurídico** (responsable vs. corresponsable vs. encargado) frente a médicos y farmacias, porque determina quién responde ante la Agencia y los titulares. Umbral de decisión: si Balance+ decide las finalidades y los medios del tratamiento, es **responsable** (escenario probable).
3. **Suscribir DPAs con todos los terceros** (mediclic, Care Assistance, Farmex, proveedores cloud) antes de la vigencia (1-dic-2026), incluyendo cláusulas de transferencia internacional si los servidores están fuera de Chile.
4. **Realizar una EIPD** (obligatoria por tratamiento masivo de datos sensibles de salud) y documentar el Registro de Actividades de Tratamiento (RAT).
5. **Corregir toda referencia a la Ley 19.628** en la UI actual y migrar al estándar 21.719; eliminar cualquier mención a un "plazo de 72 horas" como obligación legal de brechas en Chile.
6. **Designar un DPO** aunque sea voluntario: dado el tratamiento de datos sensibles a gran escala, es la mejor práctica y reduce el riesgo regulatorio; es obligatorio si se adopta el Modelo de Prevención (art. 49).
7. **Ser transparente sobre la indicación y el carácter off-label** del uso de GLP-1 para pérdida de peso, confirmando con el ISP el registro vigente de cada producto.
8. **Benchmarks que cambiarían las recomendaciones**: publicación de los reglamentos de la Ley 21.719 (pueden fijar el plazo de brechas y precisar la EIPD); resoluciones de la Agencia; eventual aprobación del proyecto que regula la autoprescripción/indicaciones clínicas (modificaría el Código Sanitario).

## Caveats
- Este informe es un **insumo de investigación**; debe ser revisado por un abogado/DPO chileno antes de publicar cualquier documento.
- Los **reglamentos de la Ley 21.719 aún se están dictando (2025-2026)**; pueden precisar plazos (incluido el de brechas) y obligaciones. Confirmar con fuente primaria (Diario Oficial, Agencia de Protección de Datos Personales).
- Los números de artículo fueron verificados contra el texto del Diario Oficial; aun así, conviene cotejar la versión consolidada en BCN/LeyChile al redactar.
- La calificación del modelo de orquestación como "no prestador" es **jurídicamente discutible**; la experiencia comparada (Ro/Hims en EE.UU., que usan la estructura PC-MSO y operan en "zonas grises") muestra que los reguladores pueden imputar responsabilidad si el orquestador influye en decisiones clínicas. Requiere opinión legal específica.
- Sobre semaglutida/GLP-1: el estado de registro e indicación por producto (Ozempic, Wegovy, etc.) en el ISP es dinámico (Wegovy estaría en proceso de registro para obesidad); **verificar con el ISP al momento de redactar** el documento 6c.
- Algunas páginas (Santa María "consentimientos" y subpáginas dinámicas) cargan contenido por JavaScript y no expusieron todos sus PDFs vía fetch; conviene revisarlas manualmente en navegador.