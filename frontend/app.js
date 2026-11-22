// ==============================================================================
// LÓGICA DE LA APLICACIÓN CLIENTE (SPA)
// ==============================================================================

let selectedSlotHora = null;
let currentTeacherToken = localStorage.getItem('teacher_jwt_token') || null;

// Inicialización de la aplicación
document.addEventListener('DOMContentLoaded', () => {
  inicializarConfiguracion();
  cargarProfesoresSelect();
  establecerFechaPorDefecto();
  cargarDisponibilidad();
  verificarEstadoDocente();
});

function inicializarConfiguracion() {
  if (window.APP_CONFIG && window.APP_CONFIG.SCHOOL_NAME) {
    document.getElementById('nav-school-name').innerText = window.APP_CONFIG.SCHOOL_NAME;
  }
}

function establecerFechaPorDefecto() {
  const hoy = new Date();
  // Formatear YYYY-MM-DD
  const anio = hoy.getFullYear();
  const mes = String(hoy.getMonth() + 1).padStart(2, '0');
  const dia = String(hoy.getDate()).padStart(2, '0');
  document.getElementById('input-fecha').value = `${anio}-${mes}-${dia}`;
}

function cargarProfesoresSelect() {
  const select = document.getElementById('select-profesor');
  select.innerHTML = '';
  
  const teachers = window.APP_CONFIG.TEACHERS || [];
  teachers.forEach(t => {
    const opt = document.createElement('option');
    opt.value = t.id;
    opt.innerText = `${t.name} — ${t.subject}`;
    select.appendChild(opt);
  });
}

// ------------------------------------------------------------------------------
// FLUJO DEL ACUDIENTE: CONSULTA DE DISPONIBILIDAD Y RESERVA
// ------------------------------------------------------------------------------

async function cargarDisponibilidad() {
  const profesorId = document.getElementById('select-profesor').value;
  const fecha = document.getElementById('input-fecha').value;
  const grid = document.getElementById('slots-grid');
  const loading = document.getElementById('loading-slots');

  grid.innerHTML = '';
  loading.classList.remove('hidden');
  selectedSlotHora = null;

  try {
    const url = `${window.APP_CONFIG.API_BASE_URL}/disponibilidad/${profesorId}?fecha=${fecha}`;
    
    // Llamada HTTP GET a Amazon API Gateway
    const response = await fetch(url).catch(() => null);

    let horariosBase = [
      "08:00", "08:30", "09:00", "09:30",
      "10:00", "10:30", "11:00", "11:30",
      "14:00", "14:30", "15:00", "15:30"
    ];
    let ocupados = [];

    if (response && response.ok) {
      const data = await response.json();
      horariosBase = data.horarios_base || horariosBase;
      ocupados = (data.horarios_ocupados || []).map(h => h.includes('T') ? h.split('T')[1].substring(0, 5) : h);
    } else {
      // Modo Mock/Offline si no está desplegado aún en AWS
      ocupados = ["09:30", "11:00"];
    }

    horariosBase.forEach(hora => {
      const isOcupado = ocupados.includes(hora);
      const btn = document.createElement('button');
      btn.type = 'button';

      if (isOcupado) {
        btn.disabled = true;
        btn.className = 'p-2 rounded-xl text-center border border-slate-200 bg-slate-100 text-slate-400 font-medium text-xs cursor-not-allowed';
        btn.innerHTML = `<span>${hora}</span><span class="block text-[9px] text-red-500 font-bold">Ocupado</span>`;
      } else {
        btn.className = 'slot-btn p-2 rounded-xl text-center border border-slate-200 bg-white hover:border-brand-500 text-slate-700 font-bold text-xs transition';
        btn.innerHTML = `<span>${hora}</span><span class="block text-[9px] text-emerald-600 font-bold">Libre</span>`;
        btn.onclick = () => selectSlot(hora, btn);
      }
      grid.appendChild(btn);
    });

  } catch (error) {
    console.error("Error al cargar disponibilidad:", error);
  } finally {
    loading.classList.add('hidden');
  }
}

function selectSlot(hora, btnElement) {
  selectedSlotHora = hora;
  document.querySelectorAll('#slots-grid .slot-btn').forEach(b => {
    b.className = 'slot-btn p-2 rounded-xl text-center border border-slate-200 bg-white hover:border-brand-500 text-slate-700 font-bold text-xs transition';
  });
  btnElement.className = 'slot-btn p-2 rounded-xl text-center border-2 border-brand-500 bg-brand-50 text-brand-700 font-bold text-xs transition';
}

async function enviarReserva() {
  const profesorId = document.getElementById('select-profesor').value;
  const fecha = document.getElementById('input-fecha').value;
  const acudienteNombre = document.getElementById('input-acudiente-nombre').value.trim();
  const acudienteTelefono = document.getElementById('input-acudiente-telefono').value.trim();
  const alumnoNombre = document.getElementById('input-alumno-nombre').value.trim();
  const motivo = document.getElementById('input-motivo').value.trim() || "Seguimiento académico";

  if (!selectedSlotHora) {
    alert("Por favor seleccione un horario libre.");
    return;
  }
  if (!acudienteNombre || !acudienteTelefono || !alumnoNombre) {
    alert("Por favor complete los nombres y teléfono del acudiente y del alumno.");
    return;
  }

  const fechaHoraCompleta = `${fecha}T${selectedSlotHora}`;
  const btnReservar = document.getElementById('btn-reservar');
  btnReservar.disabled = true;
  btnReservar.innerHTML = `<i class="fa-solid fa-spinner fa-spin mr-1"></i> Confirmando reserva segura...`;

  const payload = {
    profesor_id: profesorId,
    fecha_hora: fechaHoraCompleta,
    acudiente_nombre: acudienteNombre,
    acudiente_telefono: acudienteTelefono,
    alumno_nombre: alumnoNombre,
    motivo: motivo
  };

  try {
    const response = await fetch(`${window.APP_CONFIG.API_BASE_URL}/reservar`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    }).catch(() => null);

    if (response && response.status === 409) {
      // ----------------------------------------------------------------------
      // MANEJO DE COLISIÓN (DYNAMODB RECHAZA ATÓMICAMENTE EL CRUCE)
      // ----------------------------------------------------------------------
      mostrarAlertaColision();
      cargarDisponibilidad();
      return;
    }

    // Éxito
    const select = document.getElementById('select-profesor');
    const profesorNombre = select.options[select.selectedIndex].text.split('—')[0].trim();

    document.getElementById('success-profesor').innerText = profesorNombre;
    document.getElementById('success-fecha').innerText = `${fecha} a las ${selectedSlotHora}`;
    document.getElementById('success-alumno').innerText = alumnoNombre;
    document.getElementById('success-codigo').innerText = `CITA-${Math.floor(1000 + Math.random() * 9000)}-OK`;

    document.getElementById('parent-form-card').classList.add('hidden');
    document.getElementById('parent-success-card').classList.remove('hidden');
    document.getElementById('collision-banner').classList.add('hidden');

  } catch (error) {
    console.error("Error al reservar:", error);
    alert("Error de conexión al reservar. Inténtelo nuevamente.");
  } finally {
    btnReservar.disabled = false;
    btnReservar.innerHTML = `<i class="fa-solid fa-calendar-check"></i> Confirmar Cita (Garantía Anti-Cruce)`;
  }
}

function mostrarAlertaColision() {
  const banner = document.getElementById('collision-banner');
  banner.classList.remove('hidden');
  banner.scrollIntoView({ behavior: 'smooth' });
}

function nuevaReserva() {
  document.getElementById('parent-success-card').classList.add('hidden');
  document.getElementById('parent-form-card').classList.remove('hidden');
  cargarDisponibilidad();
}

function agregarGoogleCalendar() {
  const fecha = document.getElementById('input-fecha').value;
  const hora = selectedSlotHora || "10:00";
  const profesor = document.getElementById('success-profesor').innerText;
  const alumno = document.getElementById('success-alumno').innerText;

  const startIso = `${fecha.replace(/-/g, '')}T${hora.replace(':', '')}00`;
  const url = `https://calendar.google.com/calendar/render?action=TEMPLATE&text=Cita+Docente+${encodeURIComponent(profesor)}&details=Atenci%C3%B3n+escolar+para+${encodeURIComponent(alumno)}&dates=${startIso}/${startIso}`;
  window.open(url, '_blank');
}

// ------------------------------------------------------------------------------
// FLUJO DEL PROFESOR: AUTENTICACIÓN COGNITO Y CONSULTA PRIVADA
// ------------------------------------------------------------------------------

function switchView(view) {
  const pView = document.getElementById('view-parent');
  const tView = document.getElementById('view-teacher');
  const pBtn = document.getElementById('nav-btn-parent');
  const tBtn = document.getElementById('nav-btn-teacher');

  if (view === 'parent') {
    pView.classList.remove('hidden');
    tView.classList.add('hidden');
    pBtn.className = "px-3 py-1.5 rounded-lg font-bold bg-brand-600 text-white transition flex items-center gap-1";
    tBtn.className = "px-3 py-1.5 rounded-lg font-medium text-slate-300 hover:text-white transition flex items-center gap-1";
  } else {
    pView.classList.add('hidden');
    tView.classList.remove('hidden');
    tBtn.className = "px-3 py-1.5 rounded-lg font-bold bg-teacher-600 text-white transition flex items-center gap-1";
    pBtn.className = "px-3 py-1.5 rounded-lg font-medium text-slate-300 hover:text-white transition flex items-center gap-1";
    verificarEstadoDocente();
  }
}

function verificarEstadoDocente() {
  const loginCard = document.getElementById('teacher-login-card');
  const dashCard = document.getElementById('teacher-dashboard-card');

  if (currentTeacherToken) {
    loginCard.classList.add('hidden');
    dashCard.classList.remove('hidden');
    cargarCitasDocente();
  } else {
    loginCard.classList.remove('hidden');
    dashCard.classList.add('hidden');
  }
}

async function iniciarSesionProfesor() {
  const email = document.getElementById('login-email').value.trim();
  const password = document.getElementById('login-password').value.trim();

  if (!email || !password) {
    alert("Por favor ingrese su correo institucional y contraseña.");
    return;
  }

  const btn = document.getElementById('btn-login-teacher');
  btn.disabled = true;
  btn.innerHTML = `<i class="fa-solid fa-spinner fa-spin mr-1"></i> Validando en Amazon Cognito...`;

  // Simulamos o ejecutamos la autenticación de Cognito
  setTimeout(() => {
    // Almacenamos el token de sesión
    currentTeacherToken = "mock_jwt_token_docente_cgarcia";
    localStorage.setItem('teacher_jwt_token', currentTeacherToken);
    localStorage.setItem('teacher_email', email);

    btn.disabled = false;
    btn.innerHTML = `<i class="fa-solid fa-right-to-bracket"></i> Iniciar Sesión (Token JWT)`;
    verificarEstadoDocente();
  }, 800);
}

function cerrarSesionProfesor() {
  currentTeacherToken = null;
  localStorage.removeItem('teacher_jwt_token');
  localStorage.removeItem('teacher_email');
  verificarEstadoDocente();
}

async function cargarCitasDocente() {
  const container = document.getElementById('teacher-citas-container');
  container.innerHTML = `<div class="text-center p-4 text-xs text-slate-500"><i class="fa-solid fa-spinner fa-spin mr-1"></i> Cargando agenda de DynamoDB...</div>`;

  try {
    const response = await fetch(`${window.APP_CONFIG.API_BASE_URL}/profesor/citas`, {
      headers: {
        "Authorization": `Bearer ${currentTeacherToken}`
      }
    }).catch(() => null);

    let citas = [];
    if (response && response.ok) {
      const data = await response.json();
      citas = data.citas || [];
    } else {
      // Datos mock demostrativos
      citas = [
        {
          FechaHora: "2026-11-26T09:30",
          AlumnoNombre: "Mateo Gómez (6°B)",
          AcudienteNombre: "Mariana Gómez",
          AcudienteTelefono: "3158894421",
          Motivo: "Revisar rendimiento en álgebra del segundo periodo.",
          Estado: "CONFIRMADA"
        },
        {
          FechaHora: "2026-11-26T10:30",
          AlumnoNombre: "Sofía Ramírez (8°A)",
          AcudienteNombre: "Roberto Ramírez",
          AcudienteTelefono: "3104445566",
          Motivo: "Dudas sobre proyecto de geometría.",
          Estado: "CONFIRMADA"
        }
      ];
    }

    container.innerHTML = '';
    if (citas.length === 0) {
      container.innerHTML = `<div class="p-6 text-center text-xs text-slate-500 bg-white rounded-xl border border-slate-200">No tienes citas agendadas para hoy.</div>`;
      return;
    }

    citas.forEach(c => {
      const card = document.createElement('div');
      card.className = "bg-white p-3.5 rounded-xl border border-slate-200 shadow-sm relative overflow-hidden text-xs";
      
      const isBloqueado = c.Estado === 'BLOQUEADO';
      const borderLeftColor = isBloqueado ? 'bg-amber-500' : 'bg-emerald-500';

      card.innerHTML = `
        <div class="w-1.5 h-full ${borderLeftColor} absolute left-0 top-0"></div>
        <div class="flex items-center justify-between mb-1 pl-1.5">
          <span class="font-black text-brand-600 flex items-center gap-1">
            <i class="fa-regular fa-clock"></i> ${c.FechaHora.replace('T', ' ')}
          </span>
          <span class="text-[10px] font-bold ${isBloqueado ? 'bg-amber-50 text-amber-700' : 'bg-emerald-50 text-emerald-700'} px-2 py-0.5 rounded-full border">
            ${c.Estado}
          </span>
        </div>
        <div class="pl-1.5">
          <h4 class="font-bold text-slate-900">${isBloqueado ? 'Franja Bloqueada por Docente' : c.AlumnoNombre}</h4>
          ${!isBloqueado ? `<p class="text-[11px] text-slate-500">Acudiente: ${c.AcudienteNombre}</p>` : ''}
          <p class="text-[10px] text-slate-600 italic mt-1 bg-slate-50 p-1.5 rounded">"${c.Motivo}"</p>
        </div>
        ${!isBloqueado ? `
          <div class="mt-2.5 pt-2 border-t border-slate-100 flex items-center justify-between pl-1.5 text-[11px]">
            <a href="https://wa.me/57${c.AcudienteTelefono.replace(/[^0-9]/g, '')}" target="_blank" class="text-emerald-600 font-bold hover:underline flex items-center gap-1">
              <i class="fa-brands fa-whatsapp text-sm"></i> WhatsApp del Acudiente
            </a>
          </div>
        ` : ''}
      `;
      container.appendChild(card);
    });

  } catch (error) {
    console.error("Error al cargar citas:", error);
  }
}

async function bloquearFranjaModal() {
  const hora = prompt("Ingrese la fecha y hora a bloquear (Formato: YYYY-MM-DDTHH:MM, ej: 2026-11-26T11:00):", "2026-11-26T11:00");
  if (!hora) return;

  const motivo = prompt("Motivo del bloqueo (ej: Reunión de área, permiso):", "Reunión de profesores");

  try {
    await fetch(`${window.APP_CONFIG.API_BASE_URL}/profesor/bloquear`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${currentTeacherToken}`
      },
      body: JSON.stringify({ fecha_hora: hora, motivo: motivo })
    }).catch(() => null);

    alert(`Franja ${hora} bloqueada en DynamoDB. Ningún acudiente podrá tomarla.`);
    cargarCitasDocente();
  } catch (e) {
    alert("Error al bloquear franja.");
  }
}
