/* ============================================================================
 * bp-supabase.js — Capa de conexión Balance+ ↔ Supabase
 * Fase 2 de la salida a producción.
 *
 * Reemplaza el uso de localStorage por una API autenticada.
 * Se carga DESPUÉS de supabase-js en cada página, p. ej.:
 *
 *   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
 *   <script src="bp-supabase.js"></script>
 *
 * Expone un objeto global `BP` con auth + lectura/escritura de datos.
 * ========================================================================== */

(function () {
  'use strict';

  // --- Configuración del proyecto -------------------------------------------
  // La URL es pública. La anon/publishable key es pública POR DISEÑO (va en el
  // navegador a propósito): lo que protege los datos es la RLS, no esta llave.
  // NUNCA pongas aquí la service_role / secret key.
  const SUPABASE_URL  = 'https://dnxvftsoyoomiwfwxqmu.supabase.co';
  const SUPABASE_ANON = 'sb_publishable_PJCm0UrxkHUIyTHRKy_FDw_6F-LDE3V';

  if (!window.supabase || !window.supabase.createClient) {
    console.error('[BP] Falta cargar supabase-js antes de bp-supabase.js');
    return;
  }
  const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

  // ==========================================================================
  // AUTENTICACIÓN
  // ==========================================================================

  // Registro con correo + contraseña. Guarda nombre/apellido como metadata.
  async function signUp({ email, password, nombre, apellido }) {
    return sb.auth.signUp({
      email,
      password,
      options: { data: { nombre, apellido } }
    });
  }

  async function signIn({ email, password }) {
    return sb.auth.signInWithPassword({ email, password });
  }

  // Login social (Google ya está configurado en Supabase).
  async function signInWithGoogle(redirectTo) {
    return sb.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: redirectTo || window.location.origin + '/portal.html' }
    });
  }

  async function signOut() { return sb.auth.signOut(); }

  async function getUser() {
    const { data } = await sb.auth.getUser();
    return data ? data.user : null;
  }

  // Guardia de sesión: si no hay usuario, redirige al login. Úsalo al inicio
  // de portal.html para que nadie vea datos sin autenticarse.
  async function requireAuth(loginUrl) {
    const user = await getUser();
    if (!user) { window.location.href = loginUrl || 'index.html'; return null; }
    return user;
  }

  // ==========================================================================
  // VALIDACIÓN DE RUT (módulo 11) — el cliente valida formato, pero la
  // UNICIDAD real la garantiza la base de datos (constraint unique en patients).
  // ==========================================================================
  function cleanRut(s){ return String(s||'').replace(/[^0-9kK]/g,'').toUpperCase(); }
  function rutDV(body){ let sum=0, mul=2; for(let i=body.length-1;i>=0;i--){ sum+=parseInt(body[i],10)*mul; mul=mul===7?2:mul+1; } const r=11-(sum%11); return r===11?'0':(r===10?'K':String(r)); }
  function rutValido(s){ const c=cleanRut(s); if(c.length<2) return false; const body=c.slice(0,-1), dv=c.slice(-1); if(!/^\d+$/.test(body)||body.length<7) return false; return rutDV(body)===dv; }
  function formatRut(s){ const c=cleanRut(s); if(c.length<2) return c; let body=c.slice(0,-1), dv=c.slice(-1); body=body.replace(/\B(?=(\d{3})+(?!\d))/g,'.'); return body+'-'+dv; }

  // ==========================================================================
  // PERFIL DEL PACIENTE  (tabla patients) — reemplaza bp_profile
  // ==========================================================================

  // Lee la ficha del paciente del usuario logueado (1 fila, vía RLS).
  async function loadPatient() {
    // Trae la ficha + medicamentos. (nombre/correo se toman del usuario de Auth.)
    const { data, error } = await sb
      .from('patients')
      .select('*, medications(*)')
      .maybeSingle();
    if (error) { console.error('[BP] loadPatient', error); return null; }
    return data; // null si el paciente aún no tiene ficha
  }

  // Crea/actualiza la ficha del paciente. profile_id lo pone la RLS al validar
  // auth.uid(); aquí mandamos los campos del intake.
  async function upsertPatient(profileId, fields) {
    const row = Object.assign({ profile_id: profileId, updated_at: new Date().toISOString() }, fields);
    const { data, error } = await sb
      .from('patients')
      .upsert(row, { onConflict: 'profile_id' })
      .select()
      .maybeSingle();
    if (error) { console.error('[BP] upsertPatient', error); return { error }; }
    return { data };
  }

  // Lee los datos de cuenta del usuario actual (tabla profiles).
  async function getMyProfile() {
    const { data: u } = await sb.auth.getUser();
    if (!u || !u.user) return null;
    const { data, error } = await sb.from('profiles')
      .select('nombre,apellido,celular,email').eq('id', u.user.id).maybeSingle();
    if (error) { console.error('[BP] getMyProfile', error); return null; }
    return data;
  }

  // Actualiza datos de cuenta (tabla profiles). No toca el email (eso se cambia
  // por el flujo de Auth, con re-verificación).
  async function updateProfileFields(fields) {
    const clean = {};
    ['nombre', 'apellido', 'celular'].forEach(k => { if (fields[k] != null) clean[k] = fields[k]; });
    if (!Object.keys(clean).length) return { data: null };
    const { data: u } = await sb.auth.getUser();
    if (!u || !u.user) return { error: 'no-session' };
    clean.updated_at = new Date().toISOString();
    const { data, error } = await sb.from('profiles').update(clean).eq('id', u.user.id).select().maybeSingle();
    if (error) { console.error('[BP] updateProfileFields', error); return { error }; }
    return { data };
  }

  // Reemplaza la lista de medicamentos del paciente (medicamentos[] del intake).
  async function setMedications(patientId, meds) {
    await sb.from('medications').delete().eq('patient_id', patientId);
    if (!meds || !meds.length) return { data: [] };
    const rows = meds.map(m => ({
      patient_id: patientId,
      nombre: m.nombre,
      cantidad: m.cantidad != null ? String(m.cantidad) : null,
      frecuencia: m.frecuencia || null
    }));
    const { data, error } = await sb.from('medications').insert(rows).select();
    if (error) { console.error('[BP] setMedications', error); return { error }; }
    return { data };
  }

  // Evalúa la elegibilidad EN EL SERVIDOR (función SQL evaluate_eligibility).
  // Devuelve { result, motivo }. Las reglas no están en el cliente.
  async function evaluateEligibility(payload) {
    const { data, error } = await sb.rpc('evaluate_eligibility', { payload });
    if (error) { console.error('[BP] evaluateEligibility', error); return { error }; }
    return { data };
  }

  // Registra un evento ANÓNIMO de embudo (descalificado / llegó a resultado / etc.).
  // No guarda datos identificables; el servidor solo almacena bandas y el veredicto.
  async function logEligibility(payload, etapa) {
    const { data, error } = await sb.rpc('log_eligibility', { payload, etapa: etapa || null });
    if (error) { console.error('[BP] logEligibility', error); return { error }; }
    return { data };
  }

  // Variante para usar al CERRAR la página (evento pagehide): usa fetch con
  // keepalive para que el envío alcance a completarse aunque la pestaña se cierre.
  function logEligibilityBeacon(payload, etapa) {
    try {
      fetch(SUPABASE_URL + '/rest/v1/rpc/log_eligibility', {
        method: 'POST',
        keepalive: true,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SUPABASE_ANON,
          'Authorization': 'Bearer ' + SUPABASE_ANON
        },
        body: JSON.stringify({ payload: payload, etapa: etapa || null })
      });
    } catch (e) {}
  }

  // Guarda una ficha COMPLETA (objeto con forma de perfil del intake) en la base:
  // patients + medications + datos de cuenta en profiles. Requiere sesión activa.
  async function saveFullProfile(p) {
    const { data: u } = await sb.auth.getUser();
    if (!u || !u.user) return { error: 'no-session' };
    const uid = u.user.id;
    const num = v => (v === '' || v == null || isNaN(parseFloat(v))) ? null : parseFloat(v);
    const fields = {
      rut: p.rut || null, region: p.region || null, inscripcion: p.inscripcion || null,
      sexo: p.sexo || null, edad: num(p.edad), fecha_nacimiento: p.fecha_nacimiento || null,
      estatura: num(p.estatura), peso_inicial: num(p.peso_inicial), peso_actual: num(p.peso_actual),
      peso_objetivo: num(p.peso_objetivo), bmi: num(p.bmi), pa: p.pa || null, fc: p.fc || null,
      opioides: p.opioides == null ? null : !!p.opioides, opioide_tipo: p.opioide_tipo || null,
      cirugia: p.cirugia == null ? null : !!p.cirugia, cirugia_tipo: p.cirugia_tipo || null,
      rx: p.rx == null ? null : !!p.rx, glp1: p.glp1 == null ? null : String(p.glp1),
      otros_meds: !!p.otros_meds, programas: !!p.programas,
      condiciones: p.condiciones || [], condiciones_ninguna: !!p.condiciones_ninguna,
      exclusiones: p.exclusiones || [], exclusiones_ninguna: !!p.exclusiones_ninguna,
      excluyentes: !!p.excluyentes, exclusion_marcada: !!p.exclusion_marcada,
      medico_updates: p._updates || {}
    };
    const up = await upsertPatient(uid, fields);
    if (up.error) return { error: up.error };
    const pid = up.data && up.data.id;
    if (pid) await setMedications(pid, p.medicamentos || []);
    // Sembrar el primer registro de peso con el peso del intake.
    const pa = num(p.peso_actual) || num(p.peso_inicial);
    if (pid && pa) { await addWeightLog(pid, pa); }
    await updateProfileFields({ nombre: p.nombre, apellido: p.apellido, celular: p.celular });
    // Veredicto de elegibilidad calculado en el SERVIDOR y guardado con el envío.
    if (pid) {
      let veredicto = null;
      try {
        const e = await evaluateEligibility({ bmi: p.bmi, edad: p.edad, excluyentes: p.excluyentes });
        veredicto = e && e.data ? e.data.result : null;
      } catch (_) {}
      const sub = { patient_id: pid, intake_data: p };
      if (veredicto) sub.result = veredicto;
      const { error: subErr } = await sb.from('intake_submissions').insert(sub);
      if (subErr) console.error('[BP] intake_submissions', subErr);
    }
    return { data: pid };
  }

  // Puente intake→portal: si hay una ficha pendiente guardada localmente y el
  // usuario ya tiene sesión (correo confirmado), la crea en la base y la limpia.
  const PENDING_KEY = 'bp_pending_intake';
  async function flushPendingIntake() {
    let pend = null;
    try { pend = JSON.parse(localStorage.getItem(PENDING_KEY)); } catch (e) {}
    if (!pend) return { data: null };
    const { data: u } = await sb.auth.getUser();
    if (!u || !u.user) return { data: null };       // sin sesión aún (correo sin confirmar)
    const existing = await loadPatient();
    if (existing) { localStorage.removeItem(PENDING_KEY); return { data: existing.id }; }
    const r = await saveFullProfile(pend);
    if (!r.error) localStorage.removeItem(PENDING_KEY);
    return r;
  }
  function savePendingIntake(p) {
    try { localStorage.setItem(PENDING_KEY, JSON.stringify(p)); } catch (e) {}
  }

  // ==========================================================================
  // HISTORIAL DE PESO  (tabla weight_logs) — reemplaza bp_wlog
  // ==========================================================================
  async function loadWeightLogs(patientId) {
    const { data, error } = await sb
      .from('weight_logs')
      .select('*')
      .eq('patient_id', patientId)
      .order('logged_at', { ascending: true });
    if (error) { console.error('[BP] loadWeightLogs', error); return []; }
    return data || [];
  }

  // Reemplaza TODO el historial de peso del paciente por el arreglo dado.
  // Se usa al agregar/borrar registros desde el portal (mantiene la base = la UI).
  async function replaceWeightLogs(patientId, entries) {
    if (!patientId) return { error: 'no-patient' };
    await sb.from('weight_logs').delete().eq('patient_id', patientId);
    const rows = (entries || []).map(e => ({
      patient_id: patientId,
      weight: e.w,
      logged_at: (e.d instanceof Date ? e.d.toISOString() : new Date().toISOString())
    }));
    if (!rows.length) return { data: [] };
    const { data, error } = await sb.from('weight_logs').insert(rows).select();
    if (error) { console.error('[BP] replaceWeightLogs', error); return { error }; }
    return { data };
  }

  async function addWeightLog(patientId, weight, note) {
    const { data, error } = await sb
      .from('weight_logs')
      .insert({ patient_id: patientId, weight, note: note || null })
      .select()
      .maybeSingle();
    if (error) { console.error('[BP] addWeightLog', error); return { error }; }
    return { data };
  }

  // ==========================================================================
  // INTAKE  (tabla intake_submissions)
  // El RESULTADO de elegibilidad NO se calcula ni se guarda aquí: eso irá en
  // una Edge Function en servidor (Fase 4). Aquí solo se registra el envío.
  // ==========================================================================
  async function saveIntakeSubmission(patientId, intakeData) {
    const { data, error } = await sb
      .from('intake_submissions')
      .insert({ patient_id: patientId, intake_data: intakeData })
      .select()
      .maybeSingle();
    if (error) { console.error('[BP] saveIntakeSubmission', error); return { error }; }
    return { data };
  }

  // ==========================================================================
  // CONSENTIMIENTOS  (tabla consents) — registro inmutable, valor legal
  // ==========================================================================
  async function recordConsent(profileId, documento, version, docHash) {
    const { data, error } = await sb
      .from('consents')
      .insert({ profile_id: profileId, documento, version, doc_hash: docHash })
      .select()
      .maybeSingle();
    if (error) { console.error('[BP] recordConsent', error); return { error }; }
    return { data };
  }

  // --- API pública -----------------------------------------------------------
  window.BP = {
    sb,
    // auth
    signUp, signIn, signInWithGoogle, signOut, getUser, requireAuth,
    // rut
    cleanRut, rutValido, formatRut,
    // datos
    loadPatient, upsertPatient, updateProfileFields, getMyProfile, setMedications,
    saveFullProfile, flushPendingIntake, savePendingIntake, evaluateEligibility, logEligibility, logEligibilityBeacon,
    loadWeightLogs, addWeightLog, replaceWeightLogs,
    saveIntakeSubmission, recordConsent
  };
})();
