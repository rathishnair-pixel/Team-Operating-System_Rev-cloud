#!/usr/bin/env node
// generate-journey.js — reads FEATURE_TRACKER.json, writes results/feature-journey.html

const fs   = require('fs');
const path = require('path');

const ROOT    = path.resolve(__dirname, '..');
const TRACKER = path.join(ROOT, 'FEATURE_TRACKER.json');
const OUT     = path.join(ROOT, 'results', 'feature-journey.html');

const tracker = JSON.parse(fs.readFileSync(TRACKER, 'utf8'));
const now     = new Date().toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' });

const STAGES  = ['discovery', 'design', 'build', 'test', 'deploy'];
const SLABELS = { discovery:'Discovery', design:'Design', build:'Build', test:'Test', deploy:'Deploy' };

// ── helpers ───────────────────────────────────────────────────────────────────
function pct(f)      { return Math.round(STAGES.filter(s => (f.stages[s]||{}).status === 'complete').length / 5 * 100); }
function totalPts(f) { return (f.userStories||[]).reduce((a,s) => a + s.points, 0); }
function donePts(f)  { return (f.userStories||[]).filter(s => s.status === 'done').reduce((a,s) => a + s.points, 0); }
function hasGate(f)  { return STAGES.some(s => (f.stages[s]||{}).approval_status === 'awaiting'); }
function hasOpenDep(f) { return (f.dependencies||[]).some(d => d.status === 'open'); }
function getState(f) {
  if (STAGES.every(s => (f.stages[s]||{}).status === 'complete'))  return 'complete';
  if (STAGES.some(s  => (f.stages[s]||{}).status === 'in-progress')) return 'active';
  if (STAGES.every(s => (f.stages[s]||{}).status === 'pending'))   return 'pending';
  return 'partial';
}

function artifactLinks(artifacts) {
  if (!artifacts || !artifacts.length) return '';
  return artifacts.map(a => {
    const name = path.basename(a);
    const href = a.startsWith('results/') ? path.basename(a) : '../' + a;
    return `<a class="art-link" href="${href}" title="${a}">${name}</a>`;
  }).join('');
}

function nodeInner(status) {
  if (status === 'complete')    return `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>`;
  if (status === 'in-progress') return `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M21 12a9 9 0 11-6.2-8.56"/></svg>`;
  if (status === 'blocked')     return `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>`;
  return `<span class="node-dot"></span>`;
}

function connCls(a, b) {
  if (a === 'complete' && b === 'complete')    return 'conn-complete';
  if (a === 'complete' && b === 'in-progress') return 'conn-active';
  if (a === 'complete')                         return 'conn-done-pending';
  return 'conn-pending';
}

function dotCls(s) {
  return { complete:'dot-complete', 'in-progress':'dot-active', pending:'dot-pending', blocked:'dot-blocked' }[s] || 'dot-pending';
}

function miniPipe(f) {
  return STAGES.map((s, i) => {
    const st  = (f.stages[s]||{}).status || 'pending';
    const nxt = (f.stages[STAGES[i+1]]||{}).status || 'pending';
    const conn = i < 4 ? `<span class="mini-conn ${connCls(st,nxt)}"></span>` : '';
    return `<span class="dot ${dotCls(st)}" title="${SLABELS[s]}"></span>${conn}`;
  }).join('');
}

function gateLabel(a) { return { approved:'Approved', awaiting:'Awaiting', skipped:'Skipped', rejected:'Revise' }[a] || ''; }
function gateCls(a)   { return { approved:'gate-approved', awaiting:'gate-awaiting', skipped:'gate-skipped', rejected:'gate-rejected' }[a] || ''; }

function storyStatusCls(s)   { return { done:'ss-done', progress:'ss-progress', todo:'ss-todo', blocked:'ss-blocked' }[s] || 'ss-todo'; }
function storyStatusLabel(s) { return { done:'Done', progress:'In Progress', todo:'To Do', blocked:'Blocked' }[s] || 'To Do'; }
function spCls(p) { return p <= 2 ? 'sp-low' : p <= 5 ? 'sp-mid' : p <= 8 ? 'sp-high' : 'sp-epic'; }

function scNodeCls(s) { return { complete:'scn-complete', 'in-progress':'scn-active', pending:'scn-pending', blocked:'scn-blocked' }[s] || 'scn-pending'; }

// ── global stats ──────────────────────────────────────────────────────────────
const allFeatures = tracker.features;
const gTotalPts   = allFeatures.reduce((a,f) => a + totalPts(f), 0);
const gDonePts    = allFeatures.reduce((a,f) => a + donePts(f), 0);
const gActive     = allFeatures.filter(f => getState(f) === 'active').length;
const gOpenDeps   = allFeatures.reduce((a,f) => a + (f.dependencies||[]).filter(d=>d.status==='open').length, 0);
const gComplete   = allFeatures.filter(f => getState(f) === 'complete').length;

// ── sidebar items ─────────────────────────────────────────────────────────────
function sidebarItems() {
  return allFeatures.map(f => {
    const p  = pct(f); const tp = totalPts(f); const dp = donePts(f);
    const st = getState(f);
    const stateBadge = st === 'active'   ? '<span class="badge badge-active">Active</span>' :
                       st === 'complete' ? '<span class="badge badge-done">Done</span>'   : '';
    const gateBadge  = hasGate(f)    ? '<span class="badge badge-gate">Gate</span>'   : '';
    const depBadge   = hasOpenDep(f) ? '<span class="dep-chip-sm">⚠ Dep</span>'       : '';
    return `
      <div class="sb-item" id="sb-${f.id}" onclick="showDetail('${f.id}')">
        <div class="si-top"><span class="si-id">${f.id}</span><div class="si-badges">${stateBadge}${gateBadge}</div></div>
        <div class="si-name">${f.name}</div>
        <div class="si-pipe">${miniPipe(f)}<span class="si-pct">${p}%</span></div>
        <div class="si-bar"><div class="si-bar-fill" style="width:${p}%"></div></div>
        <div class="si-footer">
          <span class="pts-chip">${tp} pts</span>
          <span class="si-done-pts">${dp}/${tp} done</span>
          ${depBadge}
        </div>
      </div>`;
  }).join('');
}

// ── detail panel ──────────────────────────────────────────────────────────────
function stageCards(f) {
  return STAGES.map(s => {
    const st   = f.stages[s] || {};
    const stat = st.status || 'pending';
    const stPts = (f.userStories||[]).filter(u => u.stage === s).reduce((a,u) => a+u.points, 0);
    const gl   = gateLabel(st.approval_status);
    const gc   = gateCls(st.approval_status);
    const arts = artifactLinks(st.artifacts||[]);
    return `
      <div class="sc sc-${stat==='in-progress'?'active':stat}">
        <div class="sc-node ${scNodeCls(stat)}">${nodeInner(stat)}</div>
        <div class="sc-label">${SLABELS[s]}</div>
        ${st.date ? `<div class="sc-date">${st.date}</div>` : ''}
        ${stPts   ? `<div class="sc-pts"><span class="pts-chip">${stPts}p</span></div>` : ''}
        ${gl      ? `<div class="sc-gate"><span class="badge ${gc}">${gl}</span></div>` : ''}
        ${arts    ? `<div class="sc-arts">${arts}</div>` : ''}
      </div>`;
  }).join('');
}

function storiesSection(f) {
  const stories = f.userStories || [];
  if (!stories.length) return '';
  const tp = totalPts(f); const dp = donePts(f);
  let rows = '';
  STAGES.forEach(s => {
    const group = stories.filter(u => u.stage === s);
    if (!group.length) return;
    const sub = group.reduce((a,u) => a+u.points, 0);
    rows += `<tr class="sg-header"><td colspan="4">${SLABELS[s]} &mdash; ${group.length} ${group.length===1?'story':'stories'} &middot; ${sub} pts</td></tr>`;
    group.forEach(u => {
      rows += `
        <tr class="story-row">
          <td><span class="s-id">${u.id}</span></td>
          <td><span class="s-title">${u.title}</span></td>
          <td><span class="s-status ${storyStatusCls(u.status)}">${storyStatusLabel(u.status)}</span></td>
          <td><span class="sp-tag ${spCls(u.points)}">${u.points}</span></td>
        </tr>`;
    });
    rows += `<tr class="sg-sub"><td colspan="3"></td><td><span style="font-size:10px;color:var(--text-3)">${sub}p</span></td></tr>`;
  });
  rows += `
    <tr class="sg-total">
      <td colspan="2" style="font-weight:700">Total Story Points</td>
      <td style="font-size:12px;color:var(--text-2)">${dp} pts done</td>
      <td><span class="pts-chip">${tp}</span></td>
    </tr>`;
  return `
    <div class="d-section">
      <div class="d-section-head">
        <span class="d-section-title">User Stories</span>
        <span class="d-section-meta">${stories.length} stories &middot; ${tp} pts total &middot; ${dp} done</span>
      </div>
      <table class="stories-table">
        <thead><tr><th style="width:110px">ID</th><th>Story</th><th style="width:90px">Status</th><th style="width:44px;text-align:center">Pts</th></tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>`;
}

function depsSection(f) {
  const deps = f.dependencies || [];
  if (!deps.length) return '';
  const openCount = deps.filter(d => d.status === 'open').length;
  const cards = deps.map(d => {
    const isOpen = d.status === 'open';
    // dep data encoded as JSON for the modal — escape for HTML attribute
    const payload = JSON.stringify(d).replace(/'/g, '&#39;').replace(/"/g, '&quot;');
    const linked = allFeatures.find(f2 => f2.id === d.blockedBy);
    const jumpBtn = linked
      ? `<button class="dep-jump-btn" onclick="event.stopPropagation();sidebarJump('${linked.id}')">&#8594; ${linked.id}</button>`
      : '';
    return `
      <div class="dep-card ${isOpen?'dep-open':'dep-resolved'}" onclick="openDepModal('${f.id}','${d.id}')">
        <div class="dep-icon ${isOpen?'dep-icon-open':'dep-icon-resolved'}">${isOpen?'⚠':'✓'}</div>
        <div class="dep-body">
          <div class="dep-title">${d.title}</div>
          <div class="dep-desc">${d.desc}</div>
          <div class="dep-meta">
            <span class="dep-type-tag">${d.type}</span>
            <span class="dep-status-chip ${isOpen?'dsc-open':'dsc-resolved'}">${isOpen?'Open':'Resolved'}</span>
            <span class="dep-blocked-by">Blocked by: ${d.blockedByName}</span>
            ${jumpBtn}
          </div>
        </div>
        <div class="dep-arrow">&#8250;</div>
      </div>`;
  }).join('');
  return `
    <div class="d-section">
      <div class="d-section-head">
        <span class="d-section-title">Dependencies</span>
        <span class="d-section-meta">${deps.length} total${openCount ? ` &middot; <span style="color:var(--red);font-weight:700">${openCount} open</span>` : ''}</span>
      </div>
      <div class="dep-list">${cards}</div>
    </div>`;
}

function detailCards() {
  return allFeatures.map(f => {
    const p  = pct(f); const tp = totalPts(f); const dp = donePts(f);
    const st = getState(f);
    const stateBadge = st === 'active'   ? '<span class="badge badge-active">In Progress</span>' :
                       st === 'complete' ? '<span class="badge badge-done">Complete</span>'      :
                                           '<span class="badge badge-pending">Not Started</span>';
    const gateBadge = hasGate(f) ? '<span class="badge badge-gate">Gate Open</span>' : '';
    return `
      <div class="detail-card" id="dc-${f.id}" style="display:none">
        <div class="d-head">
          <div class="d-fid">${f.id}</div>
          <h2 class="d-fname">${f.name}</h2>
          <div class="d-chips">
            <span class="d-pattern">${f.pattern}</span>
            ${stateBadge}${gateBadge}
            <span class="pts-chip">${tp} pts total</span>
            <span class="d-done-pts">${dp} pts done</span>
          </div>
          <div class="d-bar"><div class="d-bar-fill" style="width:${p}%"></div></div>
        </div>
        <div class="d-stages">${stageCards(f)}</div>
        ${storiesSection(f)}
        ${depsSection(f)}
      </div>`;
  }).join('');
}

// ── dep modal data (inline JSON for JS access) ────────────────────────────────
function depModalData() {
  const map = {};
  allFeatures.forEach(f => {
    (f.dependencies||[]).forEach(d => { map[`${f.id}::${d.id}`] = { dep: d, featureId: f.id }; });
  });
  return JSON.stringify(map).replace(/<\/script>/gi, '<\\/script>');
}

// ── HTML ──────────────────────────────────────────────────────────────────────
const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="30">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Team OS &mdash; Feature Journey</title>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
:root {
  --bg:           #F5F5F7;
  --surface:      #FFFFFF;
  --border:       #D2D2D7;
  --text-1:       #1D1D1F;
  --text-2:       #6E6E73;
  --text-3:       #AEAEB2;
  --blue:         #0066CC;
  --blue-light:   #EBF3FF;
  --blue-dark:    #004499;
  --green:        #1D7D3A;
  --green-bg:     #E8F8EE;
  --green-node:   #34C759;
  --orange:       #BF4800;
  --orange-bg:    #FFF4EC;
  --orange-node:  #FF9500;
  --red:          #D70015;
  --red-bg:       #FFEBEC;
  --red-node:     #FF3B30;
  --purple:       #6B3FA0;
  --purple-bg:    #F3EEFF;
  --radius-lg:    20px;
  --radius-md:    12px;
  --radius-sm:    8px;
  --shadow:       0 2px 12px rgba(0,0,0,0.07);
  --shadow-hover: 0 6px 24px rgba(0,0,0,0.12);
  --shadow-modal: 0 24px 64px rgba(0,0,0,0.18);
}
html, body { height: 100%; overflow: hidden; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif; background: var(--bg); color: var(--text-1); -webkit-font-smoothing: antialiased; display: flex; flex-direction: column; }

/* ── NAV ── */
nav {
  flex-shrink: 0; height: 52px;
  background: rgba(245,245,247,0.88);
  backdrop-filter: saturate(180%) blur(20px);
  -webkit-backdrop-filter: saturate(180%) blur(20px);
  border-bottom: 1px solid rgba(210,210,215,0.7);
  display: flex; align-items: center; padding: 0 24px; gap: 10px;
}
.nav-logo { width: 26px; height: 26px; background: var(--text-1); border-radius: 7px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.nav-logo svg { width: 16px; height: 16px; stroke: #fff; }
.nav-title    { font-size: 15px; font-weight: 700; color: var(--text-1); letter-spacing: -0.2px; }
.nav-subtitle { font-size: 13px; color: var(--text-2); }
.nav-right    { margin-left: auto; display: flex; align-items: center; gap: 10px; }
.nav-updated  { font-size: 11px; color: var(--text-3); }
.nav-refresh  { font-size: 11px; font-weight: 500; background: var(--blue-light); color: var(--blue); padding: 3px 10px; border-radius: 20px; }

/* ── MAIN LAYOUT ── */
.app { flex: 1; display: flex; min-height: 0; }

/* ── SIDEBAR ── */
.sidebar {
  width: 292px; flex-shrink: 0;
  background: var(--surface); border-right: 1px solid var(--border);
  display: flex; flex-direction: column; overflow: hidden;
}

.sb-stats {
  display: grid; grid-template-columns: 1fr 1fr; gap: 0;
  border-bottom: 1px solid var(--border); flex-shrink: 0;
  background: var(--bg);
}
.sb-stat {
  padding: 12px 14px; text-align: center;
  border-right: 1px solid var(--border);
}
.sb-stat:nth-child(2n) { border-right: none; }
.sb-stat:nth-child(n+3) { border-top: 1px solid var(--border); }
.sb-stat-n { font-size: 22px; font-weight: 700; letter-spacing: -0.8px; line-height: 1; color: var(--text-1); }
.sb-stat-l { font-size: 10px; color: var(--text-3); margin-top: 2px; }
.sn-pts  .sb-stat-n { color: var(--purple); }
.sn-done .sb-stat-n { color: var(--green); }
.sn-gate .sb-stat-n { color: var(--blue); }
.sn-dep  .sb-stat-n { color: var(--red); }

.sb-filter {
  display: flex; gap: 4px; padding: 10px 12px;
  border-bottom: 1px solid var(--border); flex-shrink: 0; flex-wrap: wrap;
}
.sb-filter-btn {
  font-size: 10px; font-weight: 600; padding: 3px 9px; border-radius: 20px;
  border: 1px solid var(--border); background: var(--surface); color: var(--text-2); cursor: pointer; transition: all 0.12s;
}
.sb-filter-btn:hover  { border-color: var(--blue); color: var(--blue); }
.sb-filter-btn.active { background: var(--text-1); color: #fff; border-color: var(--text-1); }

.sb-list { flex: 1; overflow-y: auto; }
.sb-list::-webkit-scrollbar { width: 4px; }
.sb-list::-webkit-scrollbar-thumb { background: var(--border); border-radius: 2px; }

.sb-item {
  padding: 12px 14px; cursor: pointer;
  border-left: 3px solid transparent;
  border-bottom: 1px solid var(--bg);
  transition: background 0.1s;
}
.sb-item:hover   { background: #FAFAFA; }
.sb-item.active  { background: var(--blue-light); border-left-color: var(--blue); }

.si-top    { display: flex; align-items: center; justify-content: space-between; margin-bottom: 3px; }
.si-id     { font-size: 10px; font-weight: 700; color: var(--text-3); text-transform: uppercase; letter-spacing: 0.4px; }
.si-badges { display: flex; gap: 3px; }
.si-name   { font-size: 13px; font-weight: 500; color: var(--text-1); margin-bottom: 7px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.si-pipe   { display: flex; align-items: center; gap: 3px; margin-bottom: 4px; }
.si-pct    { font-size: 10px; color: var(--text-3); margin-left: auto; }
.si-bar    { height: 2px; background: var(--bg); border-radius: 1px; overflow: hidden; margin-bottom: 6px; }
.si-bar-fill { height: 100%; background: linear-gradient(90deg, var(--green-node), var(--blue)); border-radius: 1px; }
.si-footer { display: flex; align-items: center; gap: 5px; flex-wrap: wrap; }
.si-done-pts { font-size: 10px; color: var(--text-3); }

/* ── DETAIL PANEL ── */
.detail-panel { flex: 1; overflow-y: auto; background: var(--bg); }
.detail-panel::-webkit-scrollbar { width: 5px; }
.detail-panel::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }

.detail-empty {
  height: 100%; display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 12px;
  color: var(--text-3);
}
.detail-empty .de-arrow { font-size: 32px; }
.detail-empty p { font-size: 14px; }

.detail-card { padding: 28px 36px 48px; }

.d-head  { margin-bottom: 22px; }
.d-fid   { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-3); }
.d-fname { font-size: 26px; font-weight: 700; letter-spacing: -0.5px; margin: 4px 0 10px; line-height: 1.2; }
.d-chips { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
.d-pattern  { font-size: 11px; color: var(--text-2); background: var(--surface); border: 1px solid var(--border); padding: 3px 10px; border-radius: 20px; }
.d-done-pts { font-size: 12px; color: var(--text-2); }
.d-bar      { height: 4px; background: var(--border); border-radius: 2px; margin: 16px 0 22px; overflow: hidden; }
.d-bar-fill { height: 100%; background: linear-gradient(90deg, var(--green-node), var(--blue)); border-radius: 2px; }

/* ── STAGE CARDS ── */
.d-stages { display: grid; grid-template-columns: repeat(5,1fr); gap: 10px; margin-bottom: 28px; }
.sc {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--radius-md); padding: 14px 10px;
  text-align: center; box-shadow: var(--shadow); transition: box-shadow 0.2s;
}
.sc:hover { box-shadow: var(--shadow-hover); }
.sc-complete { border-color: rgba(52,199,89,0.3); }
.sc-active   { border-color: rgba(255,149,0,0.3); }
.sc-node { width: 40px; height: 40px; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 8px; }
.scn-complete { background: var(--green-node); color: #fff; }
.scn-active   { background: var(--orange-node); color: #fff; animation: pulse-node 2s infinite; }
.scn-pending  { background: var(--surface); border: 2px solid var(--border); color: var(--text-3); }
.scn-blocked  { background: var(--red-node); color: #fff; }
.node-dot     { width: 7px; height: 7px; border-radius: 50%; background: var(--border); display: inline-block; }
@keyframes pulse-node { 0%,100%{box-shadow:0 0 0 4px rgba(255,149,0,0.15)} 50%{box-shadow:0 0 0 8px rgba(255,149,0,0.04)} }
.sc-label { font-size: 11px; font-weight: 600; color: var(--text-1); }
.sc-date  { font-size: 10px; color: var(--text-3); margin-top: 2px; }
.sc-pts   { margin-top: 5px; }
.sc-gate  { margin-top: 5px; }
.sc-arts  { margin-top: 5px; }
.art-link { display: block; font-size: 10px; color: var(--blue); text-decoration: none; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 80px; margin: 0 auto; }
.art-link:hover { text-decoration: underline; }

/* ── SECTION ── */
.d-section { margin-bottom: 28px; }
.d-section-head { display: flex; align-items: center; justify-content: space-between; padding-bottom: 10px; margin-bottom: 12px; border-bottom: 1px solid var(--border); }
.d-section-title { font-size: 14px; font-weight: 700; color: var(--text-1); }
.d-section-meta  { font-size: 12px; color: var(--text-2); }

/* ── STORIES TABLE ── */
.stories-table { width: 100%; border-collapse: separate; border-spacing: 0 3px; }
.stories-table thead th { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.4px; color: var(--text-3); padding: 0 12px 6px; text-align: left; }
.sg-header td { padding: 8px 12px 3px; font-size: 11px; font-weight: 700; color: var(--text-2); text-transform: uppercase; letter-spacing: 0.4px; }
.story-row td { background: var(--surface); padding: 9px 12px; vertical-align: top; }
.story-row td:first-child { border-radius: var(--radius-sm) 0 0 var(--radius-sm); }
.story-row td:last-child  { border-radius: 0 var(--radius-sm) var(--radius-sm) 0; text-align: center; }
.story-row:hover td { background: #FAFAFA; }
.s-id     { font-size: 9px; font-weight: 700; color: var(--text-3); text-transform: uppercase; letter-spacing: 0.3px; display: block; }
.s-title  { font-size: 12px; color: var(--text-1); line-height: 1.45; }
.s-status { font-size: 10px; font-weight: 600; padding: 2px 8px; border-radius: 20px; white-space: nowrap; }
.ss-todo     { background: var(--bg);        color: var(--text-3); border: 1px solid var(--border); }
.ss-progress { background: var(--orange-bg); color: var(--orange); }
.ss-done     { background: var(--green-bg);  color: var(--green); }
.ss-blocked  { background: var(--red-bg);    color: var(--red); }
.sp-tag      { display: inline-flex; align-items: center; justify-content: center; min-width: 24px; height: 20px; border-radius: 10px; font-size: 11px; font-weight: 700; padding: 0 5px; }
.sp-low  { background: var(--green-bg);  color: var(--green); }
.sp-mid  { background: var(--orange-bg); color: var(--orange); }
.sp-high { background: var(--red-bg);    color: var(--red); }
.sp-epic { background: var(--purple-bg); color: var(--purple); }
.sg-sub td { padding: 2px 12px 8px; }
.sg-total td { background: var(--bg); padding: 10px 12px; font-size: 12px; font-weight: 600; }
.sg-total td:first-child { border-radius: var(--radius-sm) 0 0 var(--radius-sm); }
.sg-total td:last-child  { border-radius: 0 var(--radius-sm) var(--radius-sm) 0; text-align: center; }

/* ── DEPENDENCIES ── */
.dep-list { display: flex; flex-direction: column; gap: 8px; }
.dep-card {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--radius-md); padding: 14px 16px;
  box-shadow: var(--shadow); cursor: pointer;
  display: flex; align-items: flex-start; gap: 12px;
  transition: box-shadow 0.15s, transform 0.15s;
}
.dep-card:hover { box-shadow: var(--shadow-hover); transform: translateY(-1px); }
.dep-open     { border-color: rgba(215,0,21,0.25); }
.dep-resolved { border-color: rgba(52,199,89,0.25); opacity: 0.82; }
.dep-icon { width: 32px; height: 32px; border-radius: 50%; flex-shrink: 0; display: flex; align-items: center; justify-content: center; font-size: 14px; }
.dep-icon-open     { background: var(--red-bg); }
.dep-icon-resolved { background: var(--green-bg); }
.dep-body  { flex: 1; min-width: 0; }
.dep-title { font-size: 13px; font-weight: 600; color: var(--text-1); margin-bottom: 4px; }
.dep-desc  { font-size: 12px; color: var(--text-2); line-height: 1.45; margin-bottom: 8px; }
.dep-meta  { display: flex; gap: 6px; flex-wrap: wrap; align-items: center; }
.dep-type-tag { font-size: 9px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.4px; padding: 2px 7px; border-radius: 20px; background: var(--bg); color: var(--text-3); border: 1px solid var(--border); }
.dep-status-chip { font-size: 10px; font-weight: 700; padding: 2px 8px; border-radius: 20px; }
.dsc-open     { background: var(--red-bg);   color: var(--red); }
.dsc-resolved { background: var(--green-bg); color: var(--green); }
.dep-blocked-by { font-size: 11px; color: var(--text-3); }
.dep-jump-btn {
  font-size: 11px; font-weight: 600; color: var(--blue);
  background: var(--blue-light); border: none; border-radius: 20px;
  padding: 2px 10px; cursor: pointer;
}
.dep-jump-btn:hover { background: #d0e8ff; }
.dep-arrow { color: var(--text-3); font-size: 18px; flex-shrink: 0; padding-top: 2px; }

/* ── BADGES ── */
.badge { display: inline-flex; align-items: center; font-size: 10px; font-weight: 600; padding: 2px 8px; border-radius: 20px; white-space: nowrap; }
.badge-active   { background: var(--orange-bg);  color: var(--orange); }
.badge-done     { background: var(--green-bg);   color: var(--green); }
.badge-pending  { background: var(--bg);         color: var(--text-3); border: 1px solid var(--border); }
.badge-gate     { background: var(--blue-light); color: var(--blue); }
.badge-approved { background: var(--green-bg);   color: var(--green); border: 1px solid rgba(29,125,58,0.2); }
.gate-awaiting  { background: var(--blue-light); color: var(--blue); animation: gate-blink 2s infinite; }
.gate-approved  { background: var(--green-bg);   color: var(--green); }
.gate-rejected  { background: var(--red-bg);     color: var(--red); }
.gate-skipped   { background: var(--bg);         color: var(--text-3); border: 1px solid var(--border); }
@keyframes gate-blink { 0%,100%{opacity:1} 50%{opacity:.55} }

.pts-chip { display: inline-flex; align-items: center; font-size: 10px; font-weight: 700; padding: 2px 8px; border-radius: 20px; background: var(--purple-bg); color: var(--purple); border: 1px solid rgba(107,63,160,0.18); }
.dep-chip-sm { display: inline-flex; align-items: center; font-size: 9px; font-weight: 700; padding: 1px 6px; border-radius: 20px; background: var(--red-bg); color: var(--red); }

/* ── MINI PIPELINE (sidebar) ── */
.dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; flex-shrink: 0; }
.dot-complete { background: var(--green-node); }
.dot-active   { background: var(--orange-node); animation: gate-blink 2s infinite; }
.dot-pending  { background: var(--surface); border: 1.5px solid var(--border); }
.dot-blocked  { background: var(--red-node); }
.mini-conn { width: 10px; height: 2px; display: inline-block; border-radius: 1px; flex-shrink: 0; }
.conn-complete     { background: var(--green-node); }
.conn-active       { background: linear-gradient(90deg, var(--green-node), var(--orange-node)); }
.conn-done-pending { background: linear-gradient(90deg, var(--green-node), var(--border)); }
.conn-pending      { background: var(--border); }

/* ── DEP MODAL ── */
.modal-overlay {
  display: none; position: fixed; inset: 0; z-index: 500;
  background: rgba(0,0,0,0.36); backdrop-filter: blur(4px);
  align-items: center; justify-content: center;
}
.modal-overlay.open { display: flex; }
.modal {
  background: var(--surface); border-radius: var(--radius-lg);
  box-shadow: var(--shadow-modal); padding: 28px;
  max-width: 480px; width: calc(100% - 48px); position: relative;
  animation: modal-in 0.2s ease;
}
@keyframes modal-in { from{opacity:0;transform:scale(0.96) translateY(8px)} to{opacity:1;transform:none} }
.modal-close { position: absolute; top: 14px; right: 14px; width: 28px; height: 28px; border-radius: 50%; border: none; background: var(--bg); cursor: pointer; font-size: 15px; color: var(--text-2); display: flex; align-items: center; justify-content: center; }
.modal-close:hover { background: var(--border); }
.modal-eyebrow { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.6px; color: var(--text-3); margin-bottom: 6px; }
.modal-title   { font-size: 20px; font-weight: 700; letter-spacing: -0.3px; margin-bottom: 10px; }
.modal-desc    { font-size: 14px; color: var(--text-2); line-height: 1.55; margin-bottom: 20px; }
.modal-grid    { display: grid; grid-template-columns: 1fr 1fr; gap: 12px 16px; margin-bottom: 20px; }
.modal-field label { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.4px; color: var(--text-3); display: block; margin-bottom: 3px; }
.modal-field p     { font-size: 13px; font-weight: 500; color: var(--text-1); }
.modal-jump {
  width: 100%; padding: 11px; border: none; border-radius: var(--radius-sm);
  background: var(--blue); color: #fff; font-size: 13px; font-weight: 600;
  cursor: pointer; display: none;
}
.modal-jump:hover { background: var(--blue-dark); }

/* ── LEGEND ── */
.legend {
  flex-shrink: 0; height: 36px;
  display: flex; align-items: center; gap: 16px; padding: 0 24px;
  background: var(--surface); border-top: 1px solid var(--border);
  font-size: 11px; color: var(--text-2);
}
.legend-title { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.4px; color: var(--text-3); margin-right: 2px; }
.legend-item  { display: flex; align-items: center; gap: 5px; }
.legend-dot   { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
.ld-complete  { background: var(--green-node); }
.ld-active    { background: var(--orange-node); }
.ld-pending   { background: var(--surface); border: 1.5px solid var(--border); }
.legend-sep   { width: 1px; height: 16px; background: var(--border); }
</style>
</head>
<body>

<nav>
  <div class="nav-logo">
    <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
    </svg>
  </div>
  <span class="nav-title">Team OS</span>
  <span class="nav-subtitle">Feature Journey</span>
  <div class="nav-right">
    <span class="nav-updated">Updated ${now}</span>
    <span class="nav-refresh">Auto-refresh 30s</span>
  </div>
</nav>

<div class="app">

  <!-- SIDEBAR -->
  <div class="sidebar">
    <div class="sb-stats">
      <div class="sb-stat"><div class="sb-stat-n">${allFeatures.length}</div><div class="sb-stat-l">Features</div></div>
      <div class="sb-stat sn-pts"><div class="sb-stat-n">${gTotalPts}</div><div class="sb-stat-l">Total Pts</div></div>
      <div class="sb-stat sn-done"><div class="sb-stat-n">${gDonePts}</div><div class="sb-stat-l">Pts Done</div></div>
      <div class="sb-stat sn-gate"><div class="sb-stat-n">${gActive}</div><div class="sb-stat-l">Active</div></div>
    </div>
    <div class="sb-filter">
      <button class="sb-filter-btn active" onclick="filterSb('all',this)">All</button>
      <button class="sb-filter-btn" onclick="filterSb('active',this)">Active</button>
      <button class="sb-filter-btn" onclick="filterSb('complete',this)">Done</button>
      <button class="sb-filter-btn" onclick="filterSb('pending',this)">Not Started</button>
    </div>
    <div class="sb-list" id="sbList">
      ${sidebarItems()}
    </div>
  </div>

  <!-- DETAIL PANEL -->
  <div class="detail-panel" id="detailPanel">
    <div class="detail-empty">
      <div class="de-arrow">&#8592;</div>
      <p>Select a feature to view its pipeline, stories &amp; dependencies</p>
    </div>
    ${detailCards()}
  </div>

</div>

<!-- LEGEND -->
<div class="legend">
  <span class="legend-title">Pipeline</span>
  <span class="legend-item"><span class="legend-dot ld-complete"></span>Complete</span>
  <span class="legend-item"><span class="legend-dot ld-active"></span>In Progress</span>
  <span class="legend-item"><span class="legend-dot ld-pending"></span>Pending</span>
  <span class="legend-sep"></span>
  <span class="legend-title">Points</span>
  <span class="legend-item"><span class="sp-tag sp-low">1-2</span>Low</span>
  <span class="legend-item"><span class="sp-tag sp-mid">3-5</span>Med</span>
  <span class="legend-item"><span class="sp-tag sp-high">8</span>High</span>
  <span class="legend-item"><span class="sp-tag sp-epic">13</span>Epic</span>
  <span class="legend-sep"></span>
  <span class="legend-title">Gate</span>
  <span class="legend-item"><span class="badge gate-approved">Approved</span></span>
  <span class="legend-item"><span class="badge gate-awaiting">Awaiting</span></span>
  <span class="legend-item"><span class="badge gate-rejected">Revise</span></span>
</div>

<!-- DEP MODAL -->
<div class="modal-overlay" id="depModalOverlay" onclick="closeModal(event)">
  <div class="modal">
    <button class="modal-close" onclick="closeModal()">&#x2715;</button>
    <div class="modal-eyebrow" id="m-eyebrow"></div>
    <div class="modal-title"   id="m-title"></div>
    <div class="modal-desc"    id="m-desc"></div>
    <div class="modal-grid">
      <div class="modal-field"><label>Blocked By</label><p id="m-blocked"></p></div>
      <div class="modal-field"><label>Status</label><p id="m-status"></p></div>
      <div class="modal-field"><label>Type</label><p id="m-type"></p></div>
      <div class="modal-field"><label>Owner</label><p id="m-owner"></p></div>
    </div>
    <button class="modal-jump" id="m-jump">&#8594; View Blocking Feature</button>
  </div>
</div>

<script>
const DEP_DATA = ${depModalData()};
let activeFeatureId = null;
let jumpTarget      = null;

// ── sidebar filter ────────────────────────────────────────────────────────────
const featureStates = {
  ${allFeatures.map(f => `'${f.id}': '${getState(f)}'`).join(',\n  ')}
};
function filterSb(filter, btn) {
  document.querySelectorAll('.sb-filter-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  document.querySelectorAll('.sb-item').forEach(el => {
    const id = el.id.replace('sb-', '');
    const s  = featureStates[id];
    const show = filter === 'all'      ? true
               : filter === 'active'   ? s === 'active'
               : filter === 'complete' ? s === 'complete'
               : filter === 'pending'  ? s === 'pending'
               : true;
    el.style.display = show ? '' : 'none';
  });
}

// ── show feature detail ───────────────────────────────────────────────────────
function showDetail(id) {
  // update sidebar active state
  document.querySelectorAll('.sb-item').forEach(el => el.classList.remove('active'));
  const sbEl = document.getElementById('sb-' + id);
  if (sbEl) sbEl.classList.add('active');

  // hide empty state, hide all cards, show selected
  document.querySelectorAll('.detail-empty').forEach(el => el.style.display = 'none');
  document.querySelectorAll('.detail-card').forEach(el => el.style.display = 'none');
  const card = document.getElementById('dc-' + id);
  if (card) card.style.display = 'block';

  activeFeatureId = id;
}

// ── sidebar jump (from dep modal jump button) ─────────────────────────────────
function sidebarJump(id) {
  showDetail(id);
  const el = document.getElementById('sb-' + id);
  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

// ── dep modal ─────────────────────────────────────────────────────────────────
function openDepModal(featureId, depId) {
  const key  = featureId + '::' + depId;
  const data = DEP_DATA[key];
  if (!data) return;
  const dep  = data.dep;
  document.getElementById('m-eyebrow').textContent = 'Dependency  ·  ' + dep.type;
  document.getElementById('m-title').textContent   = dep.title;
  document.getElementById('m-desc').textContent    = dep.desc;
  document.getElementById('m-blocked').textContent = dep.blockedByName;
  document.getElementById('m-status').textContent  = dep.status === 'open' ? '⚠ Open — Blocking' : '✓ Resolved';
  document.getElementById('m-type').textContent    = dep.type;
  document.getElementById('m-owner').textContent   = dep.owner;
  const jump = document.getElementById('m-jump');
  const linked = Object.values(DEP_DATA).find(d => d.dep.id !== dep.id && d.featureId === dep.blockedBy || dep.blockedBy === d.featureId);
  // check if blockedBy matches a feature ID
  const linkedFeatureId = ${JSON.stringify(allFeatures.map(f=>f.id))}.find(id => id === dep.blockedBy);
  if (linkedFeatureId) {
    jump.style.display = 'block';
    jump.textContent   = '→ View ' + linkedFeatureId;
    jumpTarget = linkedFeatureId;
  } else {
    jump.style.display = 'none';
    jumpTarget = null;
  }
  document.getElementById('depModalOverlay').classList.add('open');
}
function closeModal(e) {
  if (!e || e.target.id === 'depModalOverlay' || e.target.classList.contains('modal-close')) {
    document.getElementById('depModalOverlay').classList.remove('open');
  }
}
document.getElementById('m-jump').onclick = function() {
  document.getElementById('depModalOverlay').classList.remove('open');
  if (jumpTarget) { showDetail(jumpTarget); sidebarJump(jumpTarget); }
};
</script>
</body>
</html>`;

fs.mkdirSync(path.join(ROOT, 'results'), { recursive: true });
fs.writeFileSync(OUT, html, 'utf8');
console.log(`✓ Feature journey written → ${OUT}`);
