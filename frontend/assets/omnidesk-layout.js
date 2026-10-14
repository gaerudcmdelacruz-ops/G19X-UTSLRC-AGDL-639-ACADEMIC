/* OmniDesk · layout compartido: cabecera + barra lateral de Configuración, filtradas por permisos (RBAC).
   Uso: <div id="app-header"></div> [<div id="app-sidebar"></div>] y OmniDesk.mount({ seccion, sub }) */
window.OmniDesk = {
  API_URL: "http://localhost:3000",
  _datos: JSON.parse(localStorage.getItem("omnidesk_sesion") || "null"),
  get session() { const d = this._datos; return { nombre: d ? d.usuario.nombre : "", permisos: d ? d.usuario.permisos : [], token: d ? d.token : null }; },
  // Llama a la API con el token. Si la sesión expiró (401), vuelve al login.
  async api(ruta, opciones = {}) {
    const r = await fetch(this.API_URL + ruta, { ...opciones,
      headers: { "Content-Type": "application/json", Authorization: "Bearer " + this.session.token, ...(opciones.headers || {}) },
      body: opciones.body ? JSON.stringify(opciones.body) : undefined });
    if (r.status === 401) { this.cerrarSesion(false); return; }
    return { ok: r.ok, status: r.status, datos: await r.json().catch(() => ({})) };
  },
  async cerrarSesion(avisar = true) {
    if (avisar && this.session.token) { try { await fetch(this.API_URL + "/api/auth/logout", { method: "POST", headers: { Authorization: "Bearer " + this.session.token } }); } catch {} }
    localStorage.removeItem("omnidesk_sesion"); location.href = "login.html";
  },
  can(p) { return !p || this.session.permisos.includes(p); },
  nav: [
    { id: "conversaciones", label: "Conversaciones", href: "conversaciones.html", perm: "conversaciones.ver_propias" },
    { id: "reportes",       label: "Reportes",       href: "reportes.html",       perm: "reportes.ver" },
    { id: "configuracion",  label: "Configuración",  href: "mi-perfil.html" }
  ],
  sidebar: [
    { id: "perfil",  label: "Mi Perfil",          icon: "account_circle",       href: "mi-perfil.html" },
    { id: "agentes", label: "Agentes",            icon: "badge",                href: "agentes.html", perm: "agentes.ver" },
    { id: "canales", label: "Canales Conectados", icon: "cell_tower",           href: "canales.html", perm: "canales.ver" },
    { id: "roles",   label: "Roles y permisos",   icon: "admin_panel_settings", href: "roles.html",   perm: "roles.ver" },
    { id: "auditoria", label: "Auditoría",        icon: "history",              href: "auditoria.html", perm: "auditoria.ver" }
  ],
  mount({ seccion, sub, permiso }) {
    if (!this.session.token) { location.href = "login.html"; return; }   // sin sesión -> login
    if (permiso && !this.can(permiso)) { location.href = "mi-perfil.html"; return; }   // sin permiso -> perfil
    const top = (i, on) => `<a href="${i.href}" ${on ? 'aria-current="page"' : ""} class="px-3.5 py-1.5 rounded-lg text-sm transition-colors ${on
      ? "text-primary font-semibold bg-surface-container border border-primary/30"
      : "text-on-surface-variant font-medium hover:text-white hover:bg-surface-container-low"}">${i.label}</a>`;
    const side = (i, on) => `<a href="${i.href}" ${on ? 'aria-current="page"' : ""} class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-all ${on
      ? "bg-surface-container-low border-l-2 border-primary text-emerald-400 font-semibold"
      : "text-tertiary font-medium hover:text-on-surface hover:bg-surface-container-low"}">
      <span class="material-symbols-outlined text-[20px] ${on ? "text-primary" : "text-tertiary"}">${i.icon}</span><span>${i.label}</span></a>`;

    document.getElementById("app-header").innerHTML = `
    <header class="fixed top-0 inset-x-0 h-16 bg-surface-container-lowest/90 backdrop-blur-xl border-b border-surface-container-high z-50 flex items-center justify-between px-6">
      <div class="flex items-center gap-8">
        <a href="conversaciones.html" class="flex items-center gap-2">
          <span class="w-9 h-9 rounded-lg bg-primary/20 border border-primary/30 flex items-center justify-center text-primary"><span class="material-symbols-outlined text-[20px]">hub</span></span>
          <span class="font-bold text-[17px] tracking-tight text-white">OmniDesk</span></a>
        <nav class="hidden md:flex items-center gap-1">${this.nav.filter(i => this.can(i.perm)).map(i => top(i, i.id === seccion)).join("")}</nav>
      </div>
      <div class="flex items-center gap-3 text-xs font-medium text-emerald-400">
        <span class="flex items-center gap-2 px-3 py-1.5 rounded-full bg-surface-container-low border border-surface-container-high"><span class="w-2 h-2 rounded-full bg-primary"></span>En línea</span>
        <button data-salir class="w-9 h-9 rounded-full bg-surface-container-high flex items-center justify-center text-on-surface hover:bg-surface-container-highest" title="${this.session.nombre} · Cerrar sesión"><span class="material-symbols-outlined text-[20px]">logout</span></button>
      </div>
    </header>`;

    const sb = document.getElementById("app-sidebar");
    if (sb) sb.innerHTML = `
    <aside class="fixed left-0 top-16 bottom-0 w-64 bg-surface-container-lowest border-r border-outline-variant z-40 flex flex-col justify-between p-4">
      <div class="flex flex-col gap-4">
        <p class="px-2 pt-2 text-[11px] font-semibold text-tertiary/70 uppercase tracking-wider">Configuración</p>
        <nav class="flex flex-col gap-1.5">${this.sidebar.filter(i => this.can(i.perm)).map(i => side(i, i.id === sub)).join("")}</nav>
      </div>
      <nav class="flex flex-col gap-1 pt-4 border-t border-surface-container-high/60">
        <a href="conversaciones.html" class="flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium text-tertiary hover:text-white hover:bg-surface-container-low"><span class="material-symbols-outlined text-[19px]">arrow_back</span>Volver al panel</a>
        <a href="login.html" data-salir class="flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium text-rose-400 hover:text-rose-300 hover:bg-rose-950/20"><span class="material-symbols-outlined text-[19px]">logout</span>Cerrar sesión</a>
      </nav>
    </aside>`;
    document.querySelectorAll("[data-salir]").forEach(a => a.addEventListener("click", e => { e.preventDefault(); this.cerrarSesion(); }));
  }
};
