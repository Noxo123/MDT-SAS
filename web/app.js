(() => {
  'use strict';
  const $ = (selector) => document.querySelector(selector);
  const state = { me: { name: 'Agent', onDuty: false, status: 'unavailable', permissions: {} }, partners: [], dispatches: [], passages: [], reports: [], agents: [] };
  const pageNames = { dashboard: 'Vue générale', dispatch: 'Dispatch opérationnel', partners: 'Entreprises partenaires', passages: 'Registre des passages', agents: 'Agents GPS', reports: 'Rapports d’intervention' };
  const statusNames = { open: 'Disponible', enroute: 'En route', onsite: 'Sur place', securing: 'Sécurisation', completed: 'Terminé', cancelled: 'Annulé', available: 'Disponible', unavailable: 'Hors service', validated: 'Validé', pending_review: 'À valider', rejected: 'Refusé' };
  const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const post = async (name, data = {}) => {
    try {
      const response = await fetch(`https://${GetParentResourceName()}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) });
      return await response.json();
    } catch (_) { return { ok: false }; }
  };
  const toast = (message, kind = 'info') => {
    const node = document.createElement('div');
    node.className = `toast ${kind}`;
    node.textContent = message;
    $('#toast-region').appendChild(node);
    setTimeout(() => node.remove(), 3500);
  };
  const moneylessStatus = (status) => statusNames[status] || status || 'Inconnu';
  const go = (page) => {
    if (!pageNames[page]) return;
    document.querySelectorAll('.page').forEach((el) => el.classList.toggle('active', el.id === `page-${page}`));
    document.querySelectorAll('.nav-item').forEach((el) => el.classList.toggle('active', el.dataset.page === page));
    $('#page-title').textContent = pageNames[page];
  };
  const empty = (message) => `<div class="muted">${escapeHtml(message)}</div>`;
  const render = () => {
    $('#agent-name').textContent = state.me.name || 'Agent';
    $('#avatar').textContent = (state.me.name || 'SA').split(/\s+/).slice(0, 2).map((s) => s[0] || '').join('').toUpperCase();
    $('#duty-label').textContent = state.me.onDuty ? 'En service' : 'Hors service';
    $('#duty-btn').textContent = state.me.onDuty ? 'Terminer mon service' : 'Prendre mon service';
    $('#stat-dispatch').textContent = state.dispatches.filter((d) => !['completed', 'cancelled'].includes(d.status)).length;
    $('#stat-agents').textContent = state.agents.length;
    $('#stat-partners').textContent = state.partners.length;
    $('#stat-passages').textContent = state.passages.filter((p) => p.day === state.today && p.status === 'validated').length;
    $('#dispatch-count').textContent = state.dispatches.filter((d) => d.status === 'open').length;
    $('#server-time').textContent = state.serverTime ? `Synchronisé : ${state.serverTime}` : 'Synchronisation active';
    const partnerSelect = $('#dispatch-partner');
    const current = partnerSelect.value;
    partnerSelect.innerHTML = '<option value="">Aucun partenaire associé</option>' + state.partners.map((p) => `<option value="${escapeHtml(p.id)}">${escapeHtml(p.name)}</option>`).join('');
    partnerSelect.value = current;
    const dispatchMarkup = (d, compact = false) => `<article class="${compact ? 'list-row' : 'dispatch-card'}"><div class="mini-icon">↗</div><div class="grow"><strong>${escapeHtml(d.title)}</strong><small>${escapeHtml(d.partnerId || 'Mission générale')} · ${escapeHtml(d.createdBy || 'Système')} · ${escapeHtml(moneylessStatus(d.status))}</small>${!compact && d.description ? `<p class="muted">${escapeHtml(d.description)}</p>` : ''}</div>${d.status === 'open' ? `<button class="button button-primary button-small" data-take="${escapeHtml(d.id)}">Prendre</button>` : ''}${!compact && state.me.permissions.supervisor && !['completed','cancelled'].includes(d.status) ? `<button class="button button-secondary button-small" data-complete="${escapeHtml(d.id)}">Terminer</button>` : ''}</article>`;
    $('#dashboard-dispatches').innerHTML = state.dispatches.length ? state.dispatches.slice(0, 4).map((d) => dispatchMarkup(d, true)).join('') : empty('Aucun dispatch.');
    $('#dispatch-list').innerHTML = state.dispatches.length ? state.dispatches.map((d) => dispatchMarkup(d)).join('') : empty('Aucun dispatch enregistré.');
    $('#partner-list').innerHTML = state.partners.length ? state.partners.map((p) => {
      const pct = Math.min(100, Math.round((p.count / Math.max(1, p.target)) * 100));
      return `<article class="partner-card"><div class="card-top"><div><h3>${escapeHtml(p.name)}</h3><div class="muted">${escapeHtml(p.address || 'Adresse non renseignée')}</div></div><span class="tag">${p.count}/${p.target} passages</span></div><div class="progress"><span style="width:${pct}%"></span></div><div class="muted">${escapeHtml(p.notes || 'Aucune consigne enregistrée.')}</div><div class="card-actions"><button class="button button-primary button-small" data-passage="${escapeHtml(p.id)}">Enregistrer ma position</button><button class="button button-secondary button-small" data-dispatch-partner="${escapeHtml(p.id)}">Créer un dispatch</button>${p.x != null && p.y != null ? `<button class="button button-secondary button-small" data-waypoint-x="${Number(p.x)}" data-waypoint-y="${Number(p.y)}">GPS partenaire</button>` : ''}</div><p class="hint">Les passages restent en attente jusqu'à la validation d'un superviseur. La position du personnage est enregistrée côté serveur au clic. Aucun média n’est demandé.</p></article>`;
    }).join('') : empty('Aucun partenaire configuré dans config.lua.');
    $('#passage-list').innerHTML = state.passages.length ? `<table class="data-table"><thead><tr><th>Heure</th><th>Partenaire</th><th>Agent</th><th>Statut</th><th>Preuve</th><th>Action</th></tr></thead><tbody>${state.passages.map((p) => { const safeEvidence = /^https?:\/\//i.test(String(p.evidence || '')); return `<tr><td>${escapeHtml(p.time || '')}</td><td>${escapeHtml(p.partnerName || p.partnerId)}</td><td>${escapeHtml(p.agent)}</td><td>${escapeHtml(moneylessStatus(p.status))}</td><td>${safeEvidence ? `<a href="${escapeHtml(p.evidence)}" target="_blank" rel="noopener noreferrer">Consulter</a>` : '—'}</td><td>${p.status === 'pending_review' && state.me.permissions.supervisor ? `<button class="button button-primary button-small" data-review-id="${escapeHtml(p.id)}" data-review-decision="validated">Valider</button> <button class="button button-secondary button-small" data-review-id="${escapeHtml(p.id)}" data-review-decision="rejected">Refuser</button>` : '—'}</td></tr>`; }).join('')}</tbody></table>` : '<div class="panel muted">Aucun passage enregistré.</div>';
    const agentMarkup = (a) => `<article class="agent-card"><div class="card-top"><div><h3>${escapeHtml(a.name)}</h3><div class="muted">ID serveur : ${escapeHtml(a.source)}</div></div><span class="tag green">${escapeHtml(moneylessStatus(a.status))}</span></div><p class="muted">${a.x == null ? 'Coordonnées indisponibles' : `X ${Number(a.x).toFixed(1)} · Y ${Number(a.y).toFixed(1)} · Z ${Number(a.z).toFixed(1)}`}</p>${a.x != null && a.y != null ? `<div class="card-actions"><button class="button button-secondary button-small" data-waypoint-x="${Number(a.x)}" data-waypoint-y="${Number(a.y)}">Placer le GPS</button></div>` : ''}</article>`;
    $('#dashboard-agents').innerHTML = state.agents.length ? state.agents.slice(0, 4).map((a) => `<div class="list-row"><div class="mini-icon">◎</div><div class="grow"><strong>${escapeHtml(a.name)}</strong><small>${escapeHtml(moneylessStatus(a.status))}</small></div></div>`).join('') : empty('Aucun agent en service.');
    $('#agent-list').innerHTML = state.agents.length ? state.agents.map(agentMarkup).join('') : empty('Aucun agent en service.');
    renderMap();
    $('#report-list').innerHTML = state.reports.length ? state.reports.map((r) => `<article class="report-card"><div class="card-top"><h3>${escapeHtml(r.title)}</h3><span class="tag">${escapeHtml(r.createdAt || '')}</span></div><p class="muted">${escapeHtml(r.body)}</p><div class="muted">Rédigé par ${escapeHtml(r.author)}</div></article>`).join('') : empty('Aucun rapport.');
  };

  function renderMap() {
    const host = $('#ops-map');
    if (!host) return;
    const agents = state.agents.filter(a => a.x != null && a.y != null && Number.isFinite(Number(a.x)) && Number.isFinite(Number(a.y)));
    const partners = state.partners.filter(p => p.x != null && p.y != null && Number.isFinite(Number(p.x)) && Number.isFinite(Number(p.y)));
    $('#map-agent-count').textContent = agents.length;
    $('#map-partner-count').textContent = partners.length;
    $('#map-updated').textContent = state.serverTime ? 'Serveur : ' + state.serverTime : 'Positions en direct';
    const all = agents.map(a => ({x:Number(a.x),y:Number(a.y)})).concat(partners.map(p => ({x:Number(p.x),y:Number(p.y)})));
    if (!all.length) { host.innerHTML = '<div class="map-empty">Aucune coordonnée disponible. Configure les partenaires et mets des agents en service.</div>'; return; }
    const minX=Math.min(...all.map(p=>p.x)), maxX=Math.max(...all.map(p=>p.x)), minY=Math.min(...all.map(p=>p.y)), maxY=Math.max(...all.map(p=>p.y));
    const spanX=Math.max(250,maxX-minX), spanY=Math.max(250,maxY-minY);
    const zoom=state.mapZoom||1, width=1000/zoom, height=600/zoom;
    const cx=state.mapCenter ? state.mapCenter.x : (minX+maxX)/2;
    const cy=state.mapCenter ? state.mapCenter.y : (minY+maxY)/2;
    const vl=cx-width/2, vt=-(cy+height/2);
    const project=(x,y)=>({x:(x-vl)/width*1000,y:(-y-vt)/height*600});
    const markers=[];
    partners.forEach(p=>{const q=project(Number(p.x),Number(p.y));markers.push('<g class="map-marker" tabindex="0" role="button" aria-label="Waypoint partenaire" data-map-x="'+Number(p.x)+'" data-map-y="'+Number(p.y)+'"><circle cx="'+q.x+'" cy="'+q.y+'" r="11" fill="#55d8a4" fill-opacity=".18"/><circle cx="'+q.x+'" cy="'+q.y+'" r="5" fill="#55d8a4" stroke="#0b1017" stroke-width="2"/><text x="'+(q.x+12)+'" y="'+(q.y-8)+'">'+escapeHtml(p.name)+'</text><text class="marker-label" x="'+(q.x+12)+'" y="'+(q.y+9)+'">PARTENAIRE</text></g>');});
    agents.forEach(a=>{const q=project(Number(a.x),Number(a.y));markers.push('<g class="map-marker" tabindex="0" role="button" aria-label="Waypoint agent" data-map-x="'+Number(a.x)+'" data-map-y="'+Number(a.y)+'"><circle cx="'+q.x+'" cy="'+q.y+'" r="14" fill="#ff626c" fill-opacity=".17"/><circle cx="'+q.x+'" cy="'+q.y+'" r="6" fill="#ff626c" stroke="#0b1017" stroke-width="2"/><text x="'+(q.x+14)+'" y="'+(q.y-9)+'">'+escapeHtml(a.name)+'</text><text class="marker-label" x="'+(q.x+14)+'" y="'+(q.y+9)+'">'+escapeHtml(moneylessStatus(a.status))+' · ID '+escapeHtml(a.source)+'</text></g>');});
    let grid=''; for(let i=0;i<=10;i++) grid+='<path d="M '+(i*100)+' 0 V 600 M 0 '+(i*60)+' H 1000" stroke="#344254" stroke-opacity=".5" stroke-width="1"/>';
    host.innerHTML='<svg viewBox="0 0 1000 600" preserveAspectRatio="xMidYMid meet" aria-label="Carte tactique GPS"><rect width="1000" height="600" fill="#0b1119"/>'+grid+markers.join('')+'</svg>';
    host.querySelectorAll('[data-map-x]').forEach(el=>{const action=()=>{const x=Number(el.dataset.mapX),y=Number(el.dataset.mapY);state.mapCenter={x:x,y:y};renderMap();post('setWaypoint',{x:x,y:y}).then(r=>{if(r&&r.ok)toast('Waypoint placé.','success');});};el.addEventListener('click',action);el.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();action();}});});
  }
  $('#map-zoom-in').addEventListener('click',()=>{state.mapZoom=Math.min(4,(state.mapZoom||1)*1.35);renderMap();});
  $('#map-zoom-out').addEventListener('click',()=>{state.mapZoom=Math.max(.5,(state.mapZoom||1)/1.35);renderMap();});
  $('#map-fit').addEventListener('click',()=>{state.mapZoom=1;state.mapCenter=null;renderMap();});

  document.querySelectorAll('.nav-item').forEach((button) => button.addEventListener('click', () => go(button.dataset.page)));
  document.querySelectorAll('[data-goto]').forEach((button) => button.addEventListener('click', () => go(button.dataset.goto)));
  $('#close-btn').addEventListener('click', () => post('close'));
  $('#duty-btn').addEventListener('click', async () => {
    state.me.onDuty = !state.me.onDuty;
    render();
    await post('setDuty', { onDuty: state.me.onDuty });
  });
  $('#dispatch-form').addEventListener('submit', async (event) => {
    event.preventDefault();
    await post('createDispatch', { title: $('#dispatch-title').value, partnerId: $('#dispatch-partner').value, description: $('#dispatch-description').value });
    $('#dispatch-title').value = '';
    $('#dispatch-description').value = '';
  });
  $('#report-form').addEventListener('submit', async (event) => {
    event.preventDefault();
    await post('createReport', { title: $('#report-title').value, body: $('#report-body').value });
    $('#report-title').value = '';
    $('#report-body').value = '';
  });
  document.addEventListener('click', async (event) => {
    const take = event.target.closest('[data-take]');
    const complete = event.target.closest('[data-complete]');
    const passage = event.target.closest('[data-passage]');
    const dispatchPartner = event.target.closest('[data-dispatch-partner]');
    const review = event.target.closest('[data-review-id]');
    const waypoint = event.target.closest('[data-waypoint-x]');
    if (take) await post('takeDispatch', { id: take.dataset.take });
    if (complete) await post('updateDispatchStatus', { id: complete.dataset.complete, status: 'completed' });
    if (passage) {
      await post('validatePassage', { partnerId: passage.dataset.passage });
    }
    if (review) await post('reviewPassage', { id: review.dataset.reviewId, decision: review.dataset.reviewDecision });
    if (waypoint) {
      const result = await post('setWaypoint', { x: Number(waypoint.dataset.waypointX), y: Number(waypoint.dataset.waypointY) });
      if (result && result.ok) toast('Point GPS placé sur la carte.', 'success');
    }
    if (dispatchPartner) {
      go('dispatch');
      $('#dispatch-partner').value = dispatchPartner.dataset.dispatchPartner;
      $('#dispatch-title').focus();
    }
  });
  document.addEventListener('keydown', (event) => { if (event.key === 'Escape') post('close'); });
  window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'setVisible') $('#app').classList.toggle('is-hidden', !data.visible);
    if (data.action === 'state' && data.state) {
      Object.assign(state, data.state);
      render();
    }
    if (data.action === 'positions') {
      state.agents = data.positions || [];
      render();
    }
    if (data.action === 'toast') toast(data.message || '', data.kind || 'info');
  });
  setInterval(() => { $('#clock').textContent = new Date().toLocaleTimeString('fr-FR'); }, 1000);
  post('requestState');
})();