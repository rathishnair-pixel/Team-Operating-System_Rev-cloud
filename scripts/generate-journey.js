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

function statusClass(status) {
  return { complete: 'complete', 'in-progress': 'active', pending: 'pending', blocked: 'blocked' }[status] || 'pending';
}

function statusIcon(status) {
  return { complete: '✓', 'in-progress': '⟳', pending: '·', blocked: '✗' }[status] || '·';
}

function statusLabel(status) {
  return { complete: 'Done', 'in-progress': 'Active', pending: '—', blocked: 'Blocked' }[status] || '—';
}

function artifactLinks(stage) {
  if (!stage.artifacts || stage.artifacts.length === 0) return '';
  return stage.artifacts.map(a => {
    const name = path.basename(a);
    // make path relative to results/ folder for the link
    const href = a.startsWith('results/') ? path.basename(a) : '../' + a;
    return `<a class="artifact-link" href="${href}" title="${a}">${name}</a>`;
  }).join('<br>');
}

function featureRows() {
  return tracker.features.map(f => {
    const cells = STAGES.map(s => {
      const stage  = f.stages[s] || { status: 'pending', artifacts: [] };
      const cls    = statusClass(stage.status);
      const icon   = statusIcon(stage.status);
      const label  = statusLabel(stage.status);
      const links  = artifactLinks(stage);
      const date   = stage.date ? `<span class="cell-date">${stage.date}</span>` : '';
      return `
        <td class="stage-cell stage-${cls}">
          <span class="stage-pill pill-${cls}">${icon} ${label}</span>
          ${date}
          ${links ? `<div class="artifacts">${links}</div>` : ''}
        </td>`;
    }).join('');

    // active stage label
    const activeStage = STAGES.find(s => (f.stages[s] || {}).status === 'in-progress');
    const activeBadge = activeStage
      ? `<span class="active-badge">⟳ ${LABELS[activeStage]}</span>`
      : '';

    return `
      <tr>
        <td class="feature-name-cell">
          <span class="fid">${f.id}</span>
          <span class="fname">${f.name}</span>
          <span class="pattern-tag">${f.pattern}</span>
          ${activeBadge}
        </td>
        ${cells}
      </tr>`;
  }).join('');
}

const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="30">
<title>Team OS — Feature Journey</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0d1117; color: #e6edf3; padding: 28px; }

  .header { display: flex; align-items: baseline; gap: 16px; margin-bottom: 24px; }
  .header h1 { font-size: 20px; font-weight: 700; color: #fff; }
  .header .project { font-size: 13px; color: #58a6ff; }
  .header .updated { font-size: 12px; color: #484f58; margin-left: auto; }
  .refresh-note { font-size: 11px; color: #484f58; margin-left: 6px; }

  table { width: 100%; border-collapse: collapse; background: #161b22; border-radius: 10px; overflow: hidden; border: 1px solid #30363d; }
  thead th { background: #21262d; color: #8b949e; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.8px; padding: 10px 14px; text-align: center; border-bottom: 1px solid #30363d; }
  thead th.col-feature { text-align: left; width: 240px; }
  tbody tr { border-bottom: 1px solid #21262d; }
  tbody tr:last-child { border-bottom: none; }
  tbody tr:hover { background: #1c2128; }

  .feature-name-cell { padding: 12px 14px; vertical-align: top; }
  .fid   { display: block; font-size: 11px; color: #8b949e; font-weight: 600; margin-bottom: 2px; }
  .fname { display: block; font-size: 13px; font-weight: 600; color: #e6edf3; margin-bottom: 4px; }
  .pattern-tag { display: inline-block; font-size: 10px; color: #8b949e; background: #21262d; padding: 2px 7px; border-radius: 10px; }
  .active-badge { display: inline-block; font-size: 10px; font-weight: 700; background: #3d2200; color: #f0883e; border: 1px solid #9e6a03; padding: 2px 8px; border-radius: 10px; margin-left: 6px; }

  .stage-cell { padding: 10px 12px; text-align: center; vertical-align: top; min-width: 110px; }
  .stage-pill { display: inline-flex; align-items: center; gap: 4px; padding: 4px 10px; border-radius: 20px; font-size: 12px; font-weight: 600; white-space: nowrap; }
  .pill-complete { background: #0d3321; color: #3fb950; border: 1px solid #238636; }
  .pill-active   { background: #3d2200; color: #f0883e; border: 1px solid #9e6a03; animation: pulse 2s infinite; }
  .pill-pending  { background: #161b22; color: #484f58; border: 1px solid #30363d; }
  .pill-blocked  { background: #3d0c0c; color: #f85149; border: 1px solid #6e1a1a; }
  @keyframes pulse { 0%,100%{box-shadow:0 0 0 0 #f0883e44} 50%{box-shadow:0 0 0 5px #f0883e00} }

  .cell-date { display: block; font-size: 10px; color: #484f58; margin-top: 4px; }
  .artifacts { margin-top: 5px; }
  .artifact-link { display: block; font-size: 10px; color: #58a6ff; text-decoration: none; max-width: 130px; margin: 0 auto; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .artifact-link:hover { text-decoration: underline; color: #79c0ff; }

  .legend { display: flex; gap: 20px; margin-top: 14px; font-size: 12px; color: #8b949e; }
  .legend-item { display: flex; align-items: center; gap: 6px; }
</style>
</head>
<body>

<div class="header">
  <h1>Team OS</h1>
  <span class="project">Feature Journey Dashboard</span>
  <span class="updated">Updated: ${now} <span class="refresh-note">(auto-refreshes every 30s)</span></span>
</div>

<table>
  <thead>
    <tr>
      <th class="col-feature">Feature</th>
      <th>Discovery</th>
      <th>Design</th>
      <th>Build</th>
      <th>Test</th>
      <th>Deploy</th>
    </tr>
  </thead>
  <tbody>
    ${featureRows()}
  </tbody>
</table>

<div class="legend">
  <span class="legend-item"><span style="color:#3fb950">✓</span> Complete</span>
  <span class="legend-item"><span style="color:#f0883e">⟳</span> In Progress</span>
  <span class="legend-item"><span style="color:#484f58">·</span> Pending</span>
  <span class="legend-item"><span style="color:#f85149">✗</span> Blocked</span>
</div>

</body>
</html>`;

fs.mkdirSync(path.join(ROOT, 'results'), { recursive: true });
fs.writeFileSync(OUT, html, 'utf8');
console.log(`✓ Feature journey written → ${OUT}`);
