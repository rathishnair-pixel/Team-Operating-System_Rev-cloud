#!/usr/bin/env node
// generate-journey.js — reads FEATURE_TRACKER.json, writes results/feature-journey.html

const fs   = require('fs');
const path = require('path');

const ROOT    = path.resolve(__dirname, '..');
const TRACKER = path.join(ROOT, 'FEATURE_TRACKER.json');
const OUT     = path.join(ROOT, 'results', 'feature-journey.html');

const tracker = JSON.parse(fs.readFileSync(TRACKER, 'utf8'));
const now     = new Date().toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' });

const STAGES = ['discovery', 'design', 'build', 'test', 'deploy'];
const LABELS = {
  discovery: 'Discovery',
  design:    'Design',
  build:     'Build',
  test:      'Test',
  deploy:    'Deploy'
};
const STAGE_ICONS = {
  discovery: 'M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z',
  design:    'M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z',
  build:     'M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4',
  test:      'M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4',
  deploy:    'M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12'
};

// ── status helpers ────────────────────────────────────────────────────────────

function nodeState(status) {
  return { complete: 'complete', 'in-progress': 'active', pending: 'pending', blocked: 'blocked' }[status] || 'pending';
}

function approvalMeta(approval_status, stage_status) {
  if (stage_status === 'pending' || !approval_status || approval_status === 'pending') return null;
  return {
    approved: { cls: 'gate-approved', label: 'Approved' },
    skipped:  { cls: 'gate-skipped',  label: 'Skipped'  },
    rejected: { cls: 'gate-rejected', label: 'Revise'   },
    awaiting: { cls: 'gate-awaiting', label: 'Awaiting' },
  }[approval_status] || null;
}

function artifactLinks(stage) {
  if (!stage.artifacts || stage.artifacts.length === 0) return '';
  return stage.artifacts.map(a => {
    const name = path.basename(a);
    const href = a.startsWith('results/') ? path.basename(a) : '../' + a;
    return `<a class="artifact-link" href="${href}" title="${a}">${name}</a>`;
  }).join('');
}

// ── summary stats ─────────────────────────────────────────────────────────────

function summaryStats() {
  const total    = tracker.features.length;
  const complete = tracker.features.filter(f =>
    STAGES.every(s => (f.stages[s] || {}).status === 'complete')).length;
  const active   = tracker.features.filter(f =>
    STAGES.some(s => (f.stages[s] || {}).status === 'in-progress')).length;
  const awaiting = tracker.features.reduce((acc, f) =>
    acc + STAGES.filter(s => (f.stages[s] || {}).approval_status === 'awaiting').length, 0);

  return `
    <div class="stats-row">
      <div class="stat-card">
        <span class="stat-num">${total}</span>
        <span class="stat-label">Features</span>
      </div>
      <div class="stat-card stat-active">
        <span class="stat-num">${active}</span>
        <span class="stat-label">In Progress</span>
      </div>
      <div class="stat-card stat-complete">
        <span class="stat-num">${complete}</span>
        <span class="stat-label">Complete</span>
      </div>
      <div class="stat-card stat-gate">
        <span class="stat-num">${awaiting}</span>
        <span class="stat-label">Gates Open</span>
      </div>
    </div>`;
}

// ── pipeline node SVG icon ────────────────────────────────────────────────────

function stageIcon(stage) {
  const d = STAGE_ICONS[stage] || '';
  return `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="${d}"/></svg>`;
}

// ── connector line between two nodes ─────────────────────────────────────────

function connector(leftStatus, rightStatus) {
  const left  = nodeState(leftStatus);
  const right = nodeState(rightStatus);
  let cls = 'conn-pending';
  if (left === 'complete' && right === 'complete') cls = 'conn-complete';
  else if (left === 'complete' && right === 'active') cls = 'conn-active';
  else if (left === 'complete') cls = 'conn-done-pending';
  return `<div class="connector ${cls}"></div>`;
}

// ── full pipeline for one feature ─────────────────────────────────────────────

function pipeline(f) {
  const nodes = STAGES.map((s, i) => {
    const stage  = f.stages[s] || { status: 'pending', approval_status: 'pending', artifacts: [] };
    const state  = nodeState(stage.status);
    const links  = artifactLinks(stage);
    const gate   = approvalMeta(stage.approval_status || 'pending', stage.status);
    const date   = stage.date ? `<span class="node-date">${stage.date}</span>` : '';

    const gateHtml = gate
      ? `<span class="gate-pill ${gate.cls}">${gate.label}</span>`
      : '';

    const linksHtml = links
      ? `<div class="node-artifacts">${links}</div>`
      : '';

    const nodeInner = state === 'complete'
      ? `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>`
      : state === 'active'
      ? stageIcon(s)
      : state === 'blocked'
      ? `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>`
      : `<span class="node-dot-inner"></span>`;

    return `
      <div class="pipeline-step">
        <div class="node-wrap">
          <div class="node node-${state}">${nodeInner}</div>
          ${i < STAGES.length - 1 ? `<div class="connector-slot" data-from="${f.stages[s]?.status || 'pending'}" data-to="${f.stages[STAGES[i+1]]?.status || 'pending'}"></div>` : ''}
        </div>
        <div class="node-label">${LABELS[s]}</div>
        ${date}
        ${gateHtml}
        ${linksHtml}
      </div>`;
  });

  // inject connectors between nodes
  const withConnectors = STAGES.map((s, i) => {
    const stage     = f.stages[s] || { status: 'pending' };
    const nextStage = f.stages[STAGES[i + 1]] || { status: 'pending' };
    const node = nodes[i];
    const conn = i < STAGES.length - 1 ? connector(stage.status, nextStage.status) : '';
    return node + conn;
  });

  return `<div class="pipeline">${withConnectors.join('')}</div>`;
}

// ── feature card ─────────────────────────────────────────────────────────────

function featureCard(f) {
  const activeStage = STAGES.find(s => (f.stages[s] || {}).status === 'in-progress');
  const allComplete = STAGES.every(s => (f.stages[s] || {}).status === 'complete');
  const hasGate     = STAGES.some(s => (f.stages[s] || {}).approval_status === 'awaiting');

  const completedCount = STAGES.filter(s => (f.stages[s] || {}).status === 'complete').length;
  const progress = Math.round((completedCount / STAGES.length) * 100);

  const cardMod = allComplete ? ' card-complete' : activeStage ? ' card-active' : '';
  const activeBadge = activeStage
    ? `<span class="feature-stage-badge badge-active">${LABELS[activeStage]}</span>`
    : allComplete
    ? `<span class="feature-stage-badge badge-done">Complete</span>`
    : `<span class="feature-stage-badge badge-pending">Not Started</span>`;

  const gateBadge = hasGate
    ? `<span class="feature-stage-badge badge-gate">Gate Open</span>`
    : '';

  return `
    <div class="feature-card${cardMod}">
      <div class="card-header">
        <div class="card-meta">
          <span class="feature-id">${f.id}</span>
          <h2 class="feature-name">${f.name}</h2>
          <span class="feature-pattern">${f.pattern}</span>
        </div>
        <div class="card-badges">
          ${activeBadge}
          ${gateBadge}
          <span class="feature-progress">${progress}%</span>
        </div>
      </div>
      <div class="progress-bar-track"><div class="progress-bar-fill" style="width:${progress}%"></div></div>
      ${pipeline(f)}
    </div>`;
}

// ── full HTML ─────────────────────────────────────────────────────────────────

const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="30">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Team OS — Feature Journey</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --bg:          #F5F5F7;
    --surface:     #FFFFFF;
    --border:      #D2D2D7;
    --text-1:      #1D1D1F;
    --text-2:      #6E6E73;
    --text-3:      #AEAEB2;
    --blue:        #0066CC;
    --blue-light:  #EBF3FF;
    --green:       #1D7D3A;
    --green-bg:    #E8F8EE;
    --green-node:  #34C759;
    --orange:      #BF4800;
    --orange-bg:   #FFF4EC;
    --orange-node: #FF9500;
    --red:         #D70015;
    --red-bg:      #FFEBEC;
    --red-node:    #FF3B30;
    --gray-node:   #C7C7CC;
    --radius-lg:   20px;
    --radius-md:   12px;
    --radius-sm:   8px;
    --shadow:      0 2px 12px rgba(0,0,0,0.08);
    --shadow-hover:0 8px 32px rgba(0,0,0,0.12);
  }

  html { font-size: 16px; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Helvetica Neue', sans-serif;
    background: var(--bg);
    color: var(--text-1);
    min-height: 100vh;
    -webkit-font-smoothing: antialiased;
  }

  /* ── NAV ── */
  .nav {
    position: sticky;
    top: 0;
    z-index: 100;
    background: rgba(245,245,247,0.85);
    backdrop-filter: saturate(180%) blur(20px);
    -webkit-backdrop-filter: saturate(180%) blur(20px);
    border-bottom: 1px solid rgba(210,210,215,0.6);
    padding: 0 48px;
    height: 56px;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .nav-brand { display: flex; align-items: center; gap: 10px; }
  .nav-logo {
    width: 26px; height: 26px;
    background: var(--text-1);
    border-radius: 7px;
    display: flex; align-items: center; justify-content: center;
  }
  .nav-logo svg { width: 16px; height: 16px; stroke: #fff; }
  .nav-title { font-size: 15px; font-weight: 600; color: var(--text-1); letter-spacing: -0.2px; }
  .nav-subtitle { font-size: 13px; color: var(--text-2); }
  .nav-right { display: flex; align-items: center; gap: 16px; }
  .nav-updated { font-size: 12px; color: var(--text-3); }
  .nav-pill {
    font-size: 11px; font-weight: 500;
    background: var(--blue-light); color: var(--blue);
    padding: 3px 10px; border-radius: 20px;
  }

  /* ── MAIN ── */
  .main { max-width: 1080px; margin: 0 auto; padding: 40px 24px 80px; }

  /* ── HERO ── */
  .hero { margin-bottom: 40px; }
  .hero h1 { font-size: 40px; font-weight: 700; letter-spacing: -1px; color: var(--text-1); line-height: 1.1; }
  .hero p  { font-size: 17px; color: var(--text-2); margin-top: 8px; font-weight: 400; }

  /* ── STATS ── */
  .stats-row {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
    margin-bottom: 32px;
  }
  .stat-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: 20px 20px 16px;
    box-shadow: var(--shadow);
  }
  .stat-num   { display: block; font-size: 36px; font-weight: 700; letter-spacing: -1.5px; color: var(--text-1); line-height: 1; }
  .stat-label { display: block; font-size: 13px; color: var(--text-2); margin-top: 4px; }
  .stat-active  .stat-num { color: var(--orange-node); }
  .stat-complete .stat-num { color: var(--green); }
  .stat-gate    .stat-num { color: var(--blue); }

  /* ── FEATURE CARD ── */
  .feature-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: 28px 32px 24px;
    margin-bottom: 16px;
    box-shadow: var(--shadow);
    transition: box-shadow 0.25s ease, transform 0.25s ease;
  }
  .feature-card:hover {
    box-shadow: var(--shadow-hover);
    transform: translateY(-1px);
  }
  .feature-card.card-active  { border-color: rgba(255,149,0,0.3); }
  .feature-card.card-complete { border-color: rgba(52,199,89,0.3); }

  /* ── CARD HEADER ── */
  .card-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    margin-bottom: 14px;
  }
  .feature-id {
    display: inline-block;
    font-size: 11px; font-weight: 600; letter-spacing: 0.5px;
    text-transform: uppercase;
    color: var(--text-3);
    margin-bottom: 4px;
  }
  .feature-name {
    font-size: 20px; font-weight: 600; letter-spacing: -0.4px;
    color: var(--text-1); margin-bottom: 6px; line-height: 1.2;
  }
  .feature-pattern {
    display: inline-block;
    font-size: 11px; color: var(--text-2);
    background: var(--bg);
    border: 1px solid var(--border);
    padding: 3px 10px; border-radius: 20px;
  }
  .card-badges { display: flex; align-items: center; gap: 8px; flex-shrink: 0; margin-left: 16px; padding-top: 2px; }
  .feature-stage-badge {
    font-size: 11px; font-weight: 600;
    padding: 4px 12px; border-radius: 20px;
    white-space: nowrap;
  }
  .badge-active   { background: var(--orange-bg); color: var(--orange); }
  .badge-done     { background: var(--green-bg);  color: var(--green);  }
  .badge-pending  { background: var(--bg);        color: var(--text-3); border: 1px solid var(--border); }
  .badge-gate     { background: var(--blue-light); color: var(--blue); }
  .feature-progress { font-size: 13px; font-weight: 600; color: var(--text-2); }

  /* ── PROGRESS BAR ── */
  .progress-bar-track {
    height: 3px; background: var(--bg);
    border-radius: 2px; margin-bottom: 28px;
    overflow: hidden;
  }
  .progress-bar-fill {
    height: 100%; border-radius: 2px;
    background: linear-gradient(90deg, var(--green-node), var(--blue));
    transition: width 0.6s ease;
  }

  /* ── PIPELINE ── */
  .pipeline {
    display: flex;
    align-items: flex-start;
    position: relative;
  }

  /* ── PIPELINE STEP ── */
  .pipeline-step {
    display: flex;
    flex-direction: column;
    align-items: center;
    min-width: 80px;
    flex: 1;
    position: relative;
  }

  /* node + connector row */
  .node-wrap {
    display: flex;
    align-items: center;
    width: 100%;
    position: relative;
  }

  /* ── NODE CIRCLE ── */
  .node {
    width: 40px; height: 40px;
    border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    flex-shrink: 0;
    position: relative;
    z-index: 2;
    transition: transform 0.2s ease;
  }
  .node:hover { transform: scale(1.1); }

  .node-complete {
    background: var(--green-node);
    box-shadow: 0 0 0 4px rgba(52,199,89,0.15);
    color: #fff;
  }
  .node-active {
    background: var(--orange-node);
    box-shadow: 0 0 0 4px rgba(255,149,0,0.2);
    color: #fff;
    animation: pulse-node 2s infinite;
  }
  .node-pending {
    background: var(--surface);
    border: 2px solid var(--border);
    color: var(--text-3);
  }
  .node-blocked {
    background: var(--red-node);
    box-shadow: 0 0 0 4px rgba(255,59,48,0.15);
    color: #fff;
  }
  .node-dot-inner {
    width: 8px; height: 8px;
    border-radius: 50%;
    background: var(--border);
  }

  @keyframes pulse-node {
    0%,100% { box-shadow: 0 0 0 4px rgba(255,149,0,0.2); }
    50%      { box-shadow: 0 0 0 8px rgba(255,149,0,0.05); }
  }

  /* ── CONNECTOR LINE ── */
  .connector {
    flex: 1;
    height: 2px;
    position: relative;
    top: 0;
    z-index: 1;
    border-radius: 1px;
    min-width: 16px;
  }
  .conn-complete     { background: var(--green-node); }
  .conn-active       { background: linear-gradient(90deg, var(--green-node), var(--orange-node)); }
  .conn-done-pending { background: linear-gradient(90deg, var(--green-node), var(--border)); }
  .conn-pending      { background: var(--border); }

  /* ── NODE LABELS ── */
  .node-label {
    font-size: 12px; font-weight: 500;
    color: var(--text-2); margin-top: 8px;
    text-align: center; letter-spacing: -0.1px;
  }
  .node-date {
    font-size: 10px; color: var(--text-3);
    display: block; text-align: center;
    margin-top: 2px;
  }

  /* ── GATE PILL (below node) ── */
  .gate-pill {
    display: inline-block;
    font-size: 9px; font-weight: 600;
    letter-spacing: 0.2px;
    padding: 2px 8px; border-radius: 20px;
    margin-top: 4px;
  }
  .gate-approved { background: var(--green-bg);  color: var(--green);  }
  .gate-skipped  { background: var(--bg);        color: var(--text-3); border: 1px solid var(--border); }
  .gate-rejected { background: var(--red-bg);    color: var(--red);    }
  .gate-awaiting {
    background: var(--blue-light); color: var(--blue);
    animation: pulse-gate 2s infinite;
  }
  @keyframes pulse-gate {
    0%,100% { opacity: 1; } 50% { opacity: 0.6; }
  }

  /* ── ARTIFACT LINKS ── */
  .node-artifacts { margin-top: 5px; text-align: center; }
  .artifact-link {
    display: block;
    font-size: 10px; font-weight: 500;
    color: var(--blue); text-decoration: none;
    max-width: 80px; overflow: hidden;
    text-overflow: ellipsis; white-space: nowrap;
    margin: 0 auto;
  }
  .artifact-link:hover { text-decoration: underline; }

  /* ── LEGEND ── */
  .legend {
    display: flex; flex-wrap: wrap;
    align-items: center; gap: 20px;
    margin-top: 32px;
    padding: 20px 24px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
  }
  .legend-title { font-size: 12px; font-weight: 600; color: var(--text-3); text-transform: uppercase; letter-spacing: 0.5px; margin-right: 4px; }
  .legend-item  { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--text-2); }
  .legend-node  { width: 16px; height: 16px; border-radius: 50%; flex-shrink: 0; }
  .ln-complete  { background: var(--green-node); }
  .ln-active    { background: var(--orange-node); }
  .ln-pending   { background: var(--surface); border: 2px solid var(--border); }
  .ln-blocked   { background: var(--red-node); }
  .legend-sep   { width: 1px; height: 20px; background: var(--border); }

  /* ── FOOTER ── */
  .footer {
    text-align: center;
    padding: 24px;
    font-size: 12px;
    color: var(--text-3);
    border-top: 1px solid var(--border);
    margin-top: 40px;
  }
</style>
</head>
<body>

<nav class="nav">
  <div class="nav-brand">
    <div class="nav-logo">
      <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
      </svg>
    </div>
    <span class="nav-title">Team OS</span>
    <span class="nav-subtitle">Feature Journey</span>
  </div>
  <div class="nav-right">
    <span class="nav-updated">Updated ${now}</span>
    <span class="nav-pill">Auto-refresh 30s</span>
  </div>
</nav>

<main class="main">

  <div class="hero">
    <h1>Feature Journey</h1>
    <p>Real-time progress across your Revenue Cloud Advanced SDLC pipeline.</p>
  </div>

  ${summaryStats()}

  ${tracker.features.map(featureCard).join('\n')}

  <div class="legend">
    <span class="legend-title">Stage</span>
    <span class="legend-item"><span class="legend-node ln-complete"></span>Complete</span>
    <span class="legend-item"><span class="legend-node ln-active"></span>In Progress</span>
    <span class="legend-item"><span class="legend-node ln-pending"></span>Pending</span>
    <span class="legend-item"><span class="legend-node ln-blocked"></span>Blocked</span>
    <span class="legend-sep"></span>
    <span class="legend-title">Gate</span>
    <span class="legend-item"><span class="gate-pill gate-approved">Approved</span></span>
    <span class="legend-item"><span class="gate-pill gate-awaiting">Awaiting</span></span>
    <span class="legend-item"><span class="gate-pill gate-rejected">Revise</span></span>
    <span class="legend-item"><span class="gate-pill gate-skipped">Skipped</span></span>
  </div>

</main>

<footer class="footer">
  Team OS v3.1 &mdash; Built with Claude Code
</footer>

</body>
</html>`;

fs.mkdirSync(path.join(ROOT, 'results'), { recursive: true });
fs.writeFileSync(OUT, html, 'utf8');
console.log(`✓ Feature journey written → ${OUT}`);
