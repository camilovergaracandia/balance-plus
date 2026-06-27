# Salida a Producción — Balance+

**Objetivo:** convertir el sitio estático actual (HTML/CSS/JS con todo el estado en `localStorage`) en una plataforma real con **API autenticada** y **lógica en el servidor**, de modo que los datos y las reglas de negocio no sean copiables ni manipulables desde el navegador.

**Fecha:** 27 de junio de 2026
**Quién construye:** tú + Claude (prioridad: simplicidad, plataformas administradas, mínimo DevOps).
**Alcance elegido:** migración end-to-end, empezando por los **datos del portal del paciente**.

---

## 0. Primero, qué significa "que no sea copiable" (expectativa honesta)

Hay que ser preciso porque esto define todo el diseño:

- **El frontend SIEMPRE es copiable.** Cualquier HTML, CSS y JavaScript que llega al navegador puede verse con "Ver código fuente". No existe forma de impedirlo (ofuscar solo molesta, no protege). Si alguien quiere clonar el *aspecto* del sitio, podrá.
- **Lo que SÍ se protege moviéndolo al servidor:**
  1. **Los datos** (perfiles, peso, recetas, historial médico) → quedan en una base de datos detrás de autenticación; nadie los ve sin permiso.
  2. **Las reglas de negocio** (motor de elegibilidad del intake, cálculos que consideres propiedad intelectual, lógica de precios) → se ejecutan en el servidor; el navegador solo recibe el resultado, nunca las reglas.
  3. **La confianza/seguridad** (quién puede hacer qué) → validado en el servidor, no en el cliente.

Conclusión: el objetivo correcto no es "frontend no copiable" (imposible), sino **"datos protegidos + lógica sensible en el servidor + autorización real"**. Eso es exactamente lo que logra esta arquitectura.

---

## 1. Arquitectura recomendada (la opción conservadora)

Para un equipo de una persona + IA, manejando **datos de salud** bajo Ley 21.719, la opción más conservadora (madura, segura, poco DevOps) es una sola plataforma administrada que ya trae base de datos, autenticación, permisos y ejecución de código en servidor:

```
┌─────────────────────────────────────────────────────────────┐
│  NAVEGADOR (público, copiable)                                │
│  index / intake / portal / proveedores ... (HTML/CSS/JS)      │
│  → Solo presentación. Sin reglas de negocio. Sin datos.       │
└───────────────┬─────────────────────────────────────────────┘
                │  HTTPS + token de sesión (JWT)
                ▼
┌─────────────────────────────────────────────────────────────┐
│  SUPABASE (región São Paulo / AWS sa-east-1)                  │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐  │
│  │ Auth        │  │ Postgres     │  │ Edge Functions      │  │
│  │ (login,     │  │ (datos +     │  │ (lógica secreta:    │  │
│  │  roles, MFA)│  │  RLS por rol)│  │  elegibilidad, etc.)│  │
│  └─────────────┘  └──────────────┘  └─────────────────────┘  │
│  ┌─────────────┐  ┌──────────────────────────────────────┐   │
│  │ Storage     │  │ Audit log (quién accede a qué)        │   │
│  │ (PDFs,      │  └──────────────────────────────────────┘   │
│  │  consents)  │                                              │
│  └─────────────┘                                              │
└─────────────────────────────────────────────────────────────┘
```

**Componentes:**

| Capa | Herramienta recomendada | Por qué |
|---|---|---|
| Hosting del frontend estático | Cloudflare Pages o Vercel | Gratis, HTTPS automático, despliegue desde Git. Reutilizas tus HTML actuales. |
| Base de datos | Supabase Postgres (región São Paulo) | Postgres es estándar, robusto, cifrado en reposo. São Paulo es la región disponible más cercana a Chile. |
| Autenticación + roles | Supabase Auth | Login, sesiones, recuperación de contraseña, MFA, roles — sin construir auth desde cero (donde más errores de seguridad se cometen). |
| Permisos por dato | Row Level Security (RLS) de Postgres | El paciente solo ve SU ficha; el médico solo sus pacientes asignados. Se aplica en la base, no en el frontend. |
| Lógica en servidor | Supabase Edge Functions (Deno/TypeScript) | Aquí vive el motor de elegibilidad y todo lo que no debe ser visible. |
| Archivos | Supabase Storage | Consentimientos firmados, recetas, PDFs, con URLs firmadas temporales. |
| Verificación de identidad (pilar "Verificación de Identidad") | Proveedor privado de KYC (cédula + selfie con prueba de vida) | **Nota: Clave Única queda descartada — no se usa en el sector privado.** Se integra un proveedor KYC comercial. Hay que evaluar vendors del mercado chileno (pendiente de verificar caso por caso). |

**Por qué Supabase y no otra cosa (para tu caso):** concentra auth + datos + lógica + permisos en un solo lugar administrado, reduce la superficie de error de seguridad, es ampliamente usado y bien documentado, y Claude puede generarte el SQL, las políticas RLS y las Edge Functions paso a paso. Alternativas como AWS/GCP "puros" dan más control pero exigen mucho más DevOps — no recomendado para builder solo+IA.

> ⚠️ **Decisión legal pendiente (para abogado/DPO):** São Paulo está en **Brasil**, no en Chile. Guardar datos de salud chilenos allí es una **transferencia internacional de datos** bajo la Ley 21.719, que exige salvaguardas. Esto NO es un bloqueo, pero el DPO debe aprobar la base legal de la transferencia (cláusulas contractuales, consentimiento informado, etc.) antes de producción. Si el DPO exige residencia estrictamente en Chile, no hay BaaS administrado con región Chile hoy, y habría que evaluar un proveedor cloud chileno con backend propio (más DevOps). No soy abogado; esto debe confirmarlo un DPO chileno.

---

## 2. Roadmap por fases (todos los pasos)

### Fase 0 — Decisiones, cuentas y base legal (antes de tocar código)

0.1. **Confirmar datos de la entidad:** razón social, RUT, domicilio legal, correo de contacto, DPO. (Ya están como placeholders pendientes en los documentos legales.)
0.2. **Revisión con abogado/DPO chileno** de: (a) transferencia internacional de datos a São Paulo, (b) base de licitud para tratar datos de salud (consentimiento), (c) retención (ficha clínica 15 años, Ley 20.584). *Sin esto no se sale a producción.*
0.3. **Crear cuentas:** GitHub (código), Supabase, Cloudflare o Vercel, y registrar/configurar el dominio definitivo.
0.4. **Definir 3 entornos:** `dev` (pruebas), `staging` (ensayo previo), `prod` (real). Nunca probar contra datos reales.
0.5. **Gestor de secretos:** decidir dónde viven las claves de API (variables de entorno en Supabase/Vercel, nunca en el HTML).

### Fase 1 — Fundaciones técnicas

1.1. **Repositorio Git:** subir los HTML actuales a GitHub para tener control de versiones e historial.
1.2. **Crear proyecto Supabase** en región São Paulo (sa-east-1).
1.3. **Diseñar el modelo de datos** (esquema Postgres). Tablas mínimas:
   - `profiles` — datos básicos del usuario autenticado (1:1 con Auth).
   - `patients` — ficha del paciente (lo que hoy es `bp_profile`): nombre, edad, región, peso inicial/actual/objetivo, IMC, antecedentes, etc.
   - `intake_submissions` — cada envío del cuestionario de 6 pasos, con timestamp y resultado de elegibilidad.
   - `weight_logs` — historial de peso (hoy `bp_wlog`).
   - `prescriptions` — recetas/medicamentos por paciente.
   - `providers` — médicos, farmacias, staff.
   - `consents` — consentimientos firmados (versión del documento, hash, fecha, IP).
   - `audit_log` — registro de accesos (obligatorio para datos de salud).
1.4. **Configurar Auth:** métodos de login (email + contraseña, magic link), plantillas de correo en español.
1.5. **Definir roles:** `paciente`, `medico`, `farmacia`, `staff/admin`.
1.6. **Escribir políticas RLS** para cada tabla (Claude las genera): p. ej. "un paciente solo puede leer/escribir filas donde `patient_id = auth.uid()`"; "un médico solo ve pacientes donde figura como tratante".

### Fase 2 — Autenticación real (reemplazar el login demo)

2.1. **Pacientes:** registro y login reales reemplazando el `localStorage`. El portal exige sesión iniciada.
2.2. **Proveedores:** reemplazar el login de demo de `proveedores.html` (médicos/farmacias/staff) por Supabase Auth con roles reales.
2.3. **MFA (segundo factor)** obligatorio para médicos, farmacias y staff (acceden a datos de muchos pacientes).
2.4. **Sesiones seguras:** tokens con expiración, cierre de sesión, recuperación de contraseña.
2.5. **Autorización en cada vista:** el frontend pide datos vía API autenticada; si no hay sesión válida, no recibe nada.

### Fase 3 — Migrar los datos del portal al servidor (tu prioridad #1)

3.1. **Mapear** los campos actuales de `bp_profile` y `bp_wlog` a las tablas `patients` / `weight_logs`.
3.2. **Reescribir `portal.html`** para leer/escribir vía la API de Supabase en lugar de `localStorage`.
3.3. **Eliminar el perfil demo** ("Valentina Morales" / `DEFAULT_PROFILE`) en producción — solo debe existir en `dev`.
3.4. **Migrar la edición del médico:** los overrides manuales (`_updates`) pasan a columnas/registros con autoría y fecha (quién cambió qué).
3.5. **Conservar la precarga** desde la calculadora (`bp_calc`) como dato no sensible en cliente, pero validándolo en servidor al registrarse.

### Fase 4 — Mover la lógica sensible al servidor (lo que la hace "no copiable")

4.1. **Motor de elegibilidad del intake** → Edge Function. Las reglas que deciden si alguien es candidato GLP-1 (exclusiones, contraindicaciones, criterios) dejan de estar en el JS visible. El navegador solo envía respuestas y recibe "candidato / no candidato / requiere revisión médica".
4.2. **Validación server-side de todo el formulario:** nunca confiar en validaciones del cliente; se repiten en el servidor.
4.3. **Calculadora de proyección de peso:** decide si la consideras IP. Si sí, va a Edge Function; si es solo marketing, puede quedar en cliente. (Recomendación conservadora: servidor, para no exponer la fórmula/parámetros.)
4.4. **Cualquier lógica de precios, descuentos o asignación médico/farmacia** → servidor.

### Fase 5 — Consentimientos y documentos legales (con peso jurídico)

5.1. **Registrar cada consentimiento firmado** en la tabla `consents`: qué documento, qué versión, hash del texto, fecha/hora, identificador del usuario. Esto es prueba legal (Ley 20.584 / 21.719).
5.2. **Generar PDFs en el servidor** (no en el cliente) para que el documento firmado sea íntegro y verificable.
5.3. **Resolver los pendientes legales del PROJECT_BRIEF** antes de publicar: separar nota pública/interna en docs 01–06c, completar placeholders (EIPD doc 03, proveedores analíticos/marketing doc 05, razón social/RUT), validación médica del doc 06c. *Ningún documento sale sin revisión de abogado/DPO.*
5.4. **Aviso resumido in-app (doc 09)** insertado como capa corta en registro/consulta/perfil.

### Fase 6 — Seguridad y cumplimiento (Ley 21.719 + datos de salud)

6.1. **Cifrado:** en tránsito (HTTPS en todo) y en reposo (Supabase lo provee). Verificar.
6.2. **Audit log activo:** registrar cada acceso a datos de salud (quién, qué, cuándo). Requisito de trazabilidad.
6.3. **Backups y retención:** backups automáticos; política de retención alineada a los 15 años de ficha clínica (Ley 20.584).
6.4. **Gestión de brechas:** procedimiento para notificar "sin dilaciones indebidas" (ojo: **la ley chilena NO tiene el plazo de 72 horas del GDPR** — ya corregido en tu documentación).
6.5. **Mínimo privilegio:** cada rol accede solo a lo necesario (lo aplican las RLS).
6.6. **Rate limiting / anti-abuso** en endpoints públicos (registro, intake) para evitar scraping y ataques.
6.7. **Secretos fuera del frontend:** ninguna clave de servicio (service_role) en el navegador; solo la clave pública anónima, restringida por RLS.

### Fase 7 — Despliegue y operación

7.1. **CI/CD:** despliegue automático desde Git a Cloudflare/Vercel (frontend) y a Supabase (migraciones de base de datos).
7.2. **Dominio + DNS + certificados** TLS.
7.3. **Monitoreo:** logs, alertas de errores, métricas de uso.
7.4. **Pruebas:** funcionales (flujos completos), de seguridad (intentar acceder a datos de otro usuario), y carga básica.

### Fase 8 — Go-live

8.1. **Checklist pre-producción:** legal aprobado, placeholders reemplazados, MFA activo, RLS probada, backups corriendo, demo eliminado.
8.2. **Soft launch / beta** con usuarios reales limitados antes de abrir del todo.
8.3. **Plan de soporte e incidentes** definido.

---

## 3. Orden sugerido de ejecución (camino más corto a valor)

Dado que tu prioridad es **datos del portal** y **end-to-end**, el orden pragmático es:

1. Fase 0 (cuentas + luz verde legal del DPO) — *bloqueante.*
2. Fase 1 (Supabase + esquema + RLS).
3. Fase 2 (auth real de pacientes y proveedores).
4. Fase 3 (portal deja de usar `localStorage`). ← **primer gran hito visible**
5. Fase 4 (elegibilidad y lógica al servidor). ← **aquí dejas de ser "copiable"**
6. Fases 5–6 (consentimientos + seguridad/cumplimiento).
7. Fases 7–8 (despliegue y salida).

---

## 4. Costos y tiempos (estimaciones — verificar)

- **Costo inicial:** Supabase y Cloudflare/Vercel tienen capa gratuita para empezar. El plan **Supabase Pro ronda los USD 25/mes** *(aproximado, verificar precio actual)*; el KYC se cobra por verificación *(tarifa por confirmar con el proveedor que elijan)*.
- **Tiempo:** depende del ritmo de trabajo tuyo + IA. No me arriesgo a dar un número de semanas sin conocer tu disponibilidad; lo estimamos al cerrar la Fase 1.

---

## 5. Advertencias finales (verdad por sobre conveniencia)

- **No soy abogado ni DPO.** Toda afirmación legal (transferencia internacional, retención, consentimientos) debe ser validada por un profesional chileno antes de producción.
- **Clave Única: descartada para sector privado** (confirmado por ti). La verificación de identidad se hace con un proveedor KYC comercial; aún hay que elegirlo y verificar su encaje legal.
- **Datos sensibles a la fecha** (precios, regiones, proveedores KYC, condiciones de Supabase): verificar contra la fuente oficial al momento de contratar, porque cambian.
- **"No copiable" tiene un límite real:** se protegen datos y lógica de servidor, no la apariencia del frontend.

---

### Anexo — Mapa de migración rápida (de hoy → a producción)

| Hoy (estático) | Mañana (producción) |
|---|---|
| `localStorage.bp_profile` | Tabla `patients` + RLS |
| `localStorage.bp_wlog` | Tabla `weight_logs` + RLS |
| `localStorage.bp_calc` | Dato no sensible en cliente, revalidado en servidor |
| Login demo de `proveedores.html` | Supabase Auth con roles + MFA |
| Reglas de elegibilidad en JS visible | Edge Function (ocultas) |
| Perfil demo "Valentina Morales" | Solo en `dev`; eliminado en `prod` |
| PDFs/consentimientos en cliente | Generados y registrados en servidor (`consents` + Storage) |
| Sin registro de accesos | `audit_log` obligatorio |
