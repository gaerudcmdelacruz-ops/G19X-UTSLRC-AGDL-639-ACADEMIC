/* OmniDesk · layout compartido: cabecera + barra lateral de Configuración, filtradas por permisos (RBAC).
   Uso: <div id="app-header"></div> [<div id="app-sidebar"></div>] y OmniDesk.mount({ seccion, sub }) */
// Ícono de la pestaña del navegador (una sola vez para todas las páginas que cargan este archivo)
(function () {
  if (document.querySelector('link[rel="icon"]')) return;
  const a = document.createElement("link"); a.rel = "icon"; a.type = "image/png"; a.href = "assets/favicon.png";
  const b = document.createElement("link"); b.rel = "apple-touch-icon"; b.href = "assets/apple-touch-icon.png";
  document.head.append(a, b);
})();
window.OmniDesk = {
  API_URL: "http://localhost:3000",
  // Escapa texto antes de meterlo en innerHTML (evita XSS). Única copia: úsala como OmniDesk.esc()
  esc: s => String(s == null ? "" : s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])),
  _datos: JSON.parse(localStorage.getItem("omnidesk_sesion") || "null"),
  get session() { const d = this._datos; return { nombre: d ? d.usuario.nombre : "", permisos: d ? d.usuario.permisos : [], token: d ? d.token : null, foto: d ? d.usuario.foto || null : null }; },
  // Avatar: la foto si existe; si no, las iniciales. Los elementos con data-avatar se repintan con pintarAvatares().
  iniciales(nombre) { return String(nombre || "?").split(" ").filter(Boolean).map(n => n[0]).slice(0, 2).join("").toUpperCase(); },
  fotoUrl(foto) { return foto ? this.API_URL + "/uploads/avatares/" + encodeURIComponent(foto) : null; },
  avatarHtml() {
    const url = this.fotoUrl(this.session.foto);
    return url ? `<img src="${url}" alt="Foto de ${this.esc(this.session.nombre)}" class="w-full h-full object-cover">`
               : `<span class="text-[13px] font-bold">${this.esc(this.iniciales(this.session.nombre))}</span>`;
  },
  pintarAvatares() { document.querySelectorAll("[data-avatar]").forEach(el => { el.innerHTML = this.avatarHtml(); }); },
  // Guarda la foto nueva (o null) en la sesión del navegador y actualiza todos los avatares visibles.
  guardarFoto(foto) {
    if (!this._datos) return;
    this._datos.usuario.foto = foto || null;
    try { localStorage.setItem("omnidesk_sesion", JSON.stringify(this._datos)); } catch {}
    this.pintarAvatares();
  },
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

    const mov = (i, on) => `<a href="${i.href}" ${on ? 'aria-current="page"' : ""} class="block px-3 py-3 rounded-lg text-sm ${on
      ? "text-primary font-semibold bg-surface-container"
      : "text-on-surface-variant font-medium hover:text-white hover:bg-surface-container-low"}">${i.label}</a>`;

    document.getElementById("app-header").innerHTML = `
    <header class="fixed top-0 inset-x-0 h-16 bg-surface-container-lowest/90 backdrop-blur-xl border-b border-surface-container-high z-50 flex items-center justify-between px-4 sm:px-6">
      <div class="flex items-center gap-3 md:gap-8">
        <button id="btn-menu" type="button" aria-label="Abrir menú" aria-expanded="false" class="md:hidden w-9 h-9 rounded-lg bg-surface-container-high flex items-center justify-center text-on-surface"><span class="material-symbols-outlined text-[22px]">menu</span></button>
        <a href="conversaciones.html" class="flex items-center gap-2">
          <img src="assets/logo.png" alt="Logo de OmniDesk" width="36" height="36" class="w-9 h-9 object-contain">
          <span class="font-bold text-[17px] tracking-tight text-white">OmniDesk</span></a>
        <nav class="hidden md:flex items-center gap-1">${this.nav.filter(i => this.can(i.perm)).map(i => top(i, i.id === seccion)).join("")}</nav>
      </div>
      <div class="flex items-center gap-2 sm:gap-3 text-xs font-medium text-emerald-400">
        <span title="En línea" class="flex items-center gap-2 px-2.5 sm:px-3 py-1.5 rounded-full bg-surface-container-low border border-surface-container-high"><span class="w-2 h-2 rounded-full bg-primary"></span><span class="hidden sm:inline">En línea</span></span>
        <a href="mi-perfil.html" data-avatar title="${this.esc(this.session.nombre)} · Mi perfil" class="w-9 h-9 rounded-full overflow-hidden bg-[#031427] border border-emerald-500/40 text-emerald-300 flex items-center justify-center hover:border-emerald-400">${this.avatarHtml()}</a>
        <button data-salir class="w-9 h-9 rounded-full bg-surface-container-high flex items-center justify-center text-on-surface hover:bg-surface-container-highest" title="${this.session.nombre} · Cerrar sesión"><span class="material-symbols-outlined text-[20px]">logout</span></button>
      </div>
    </header>
    <nav id="menu-movil" aria-label="Menú principal" class="hidden md:hidden fixed top-16 inset-x-0 z-40 bg-surface-container-lowest/95 backdrop-blur-xl border-b border-surface-container-high p-3 flex flex-col gap-1">${this.nav.filter(i => this.can(i.perm)).map(i => mov(i, i.id === seccion)).join("")}</nav>`;
    const bm = document.getElementById("btn-menu"), mm = document.getElementById("menu-movil");
    if (bm && mm) bm.addEventListener("click", () => { const abierto = !mm.classList.toggle("hidden"); bm.setAttribute("aria-expanded", String(abierto)); });

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
