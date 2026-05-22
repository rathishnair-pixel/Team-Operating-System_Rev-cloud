#!/usr/bin/env bash
# Team OS — Onboarding Installer
# Idempotent: safe to run multiple times. Each step is skipped if already done.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[ok]${NC}  $*"; }
skip() { echo -e "${YELLOW}[skip]${NC} $*"; }
fail() { echo -e "${RED}[fail]${NC} $*"; exit 1; }
step() { echo -e "\n${YELLOW}==>${NC} $*"; }

# ── 1. Prerequisites check ────────────────────────────────────────────────────
step "Checking prerequisites"

command -v node  >/dev/null 2>&1 || fail "Node.js not found. Install via: brew install node"
command -v npm   >/dev/null 2>&1 || fail "npm not found. Install via: brew install node"
command -v sf    >/dev/null 2>&1 || { echo ""; echo "  Warning: Salesforce CLI (sf) not found."; echo "  Install via: npm install -g @salesforce/cli"; echo "  Continuing setup — install sf before org operations."; }

ok "Node $(node --version), npm $(npm --version)"

# ── 2. npm dependencies ───────────────────────────────────────────────────────
step "Installing npm dependencies"

if [ -f "$ROOT/package.json" ]; then
  if [ ! -d "$ROOT/node_modules" ] || [ "$ROOT/package.json" -nt "$ROOT/node_modules/.package-lock.json" ]; then
    npm install --prefix "$ROOT" --silent
    ok "npm install complete"
  else
    skip "node_modules up to date"
  fi
else
  skip "No package.json found — skipping npm install"
fi

# ── 3. Mermaid CLI (for DOCX generation) ─────────────────────────────────────
step "Checking Mermaid CLI"

if command -v mmdc >/dev/null 2>&1; then
  skip "mmdc already installed ($(mmdc --version 2>/dev/null || echo 'version unknown'))"
else
  echo "  Installing @mermaid-js/mermaid-cli globally..."
  npm install -g @mermaid-js/mermaid-cli --silent
  ok "mmdc installed"
fi

# ── 4. Pandoc (for DOCX generation) ──────────────────────────────────────────
step "Checking pandoc"

if command -v pandoc >/dev/null 2>&1; then
  skip "pandoc already installed ($(pandoc --version | head -1))"
else
  if command -v brew >/dev/null 2>&1; then
    brew install pandoc --quiet
    ok "pandoc installed via brew"
  else
    echo "  Warning: pandoc not found and brew unavailable."
    echo "  Install manually: https://pandoc.org/installing.html"
  fi
fi

# ── 5. Directory scaffolding ──────────────────────────────────────────────────
step "Creating directory structure"

for dir in results .context-cache .context-cache/schema .context-cache/pre-edit; do
  if [ ! -d "$ROOT/$dir" ]; then
    mkdir -p "$ROOT/$dir"
    ok "Created $dir/"
  else
    skip "$dir/ exists"
  fi
done

# ── 6. .gitignore — protect context cache ────────────────────────────────────
step "Updating .gitignore"

GITIGNORE="$ROOT/.gitignore"
touch "$GITIGNORE"

add_if_missing() {
  grep -qxF "$1" "$GITIGNORE" || echo "$1" >> "$GITIGNORE"
}

add_if_missing ".context-cache/"
add_if_missing "node_modules/"
add_if_missing ".DS_Store"
ok ".gitignore updated"

# ── 7. Write .mcp.json ────────────────────────────────────────────────────────
step "Checking .mcp.json"

MCP_JSON="$ROOT/.mcp.json"
NODE_BIN="$(which node)"
LAUNCHER="$HOME/.mcp-adaptor/bin/mcp-adaptor-launcher.js"
RCA_SERVER="/tmp/revenue-cloud-advanced-architect-assistant/mcp-server/dist/index.js"

if [ ! -f "$MCP_JSON" ]; then
  cat > "$MCP_JSON" <<EOF
{
  "mcpServers": {
    "mcp-adaptor": {
      "command": "$NODE_BIN",
      "args": ["$LAUNCHER"],
      "transport": "stdio",
      "env": {
        "MCP_ADAPTOR_ENV": "prod",
        "MCP_IDE_CLIENT": "claude-code",
        "GW_PROFILE": "search"
      }
    },
    "user-rca-advisor": {
      "command": "$NODE_BIN",
      "args": ["$RCA_SERVER"],
      "transport": "stdio"
    }
  }
}
EOF
  ok ".mcp.json written"
else
  skip ".mcp.json already exists"
fi

# ── 8. mcp-adaptor auth reminder ─────────────────────────────────────────────
step "MCP Adaptor auth check"

if [ -f "$LAUNCHER" ]; then
  ok "mcp-adaptor-launcher.js found at $LAUNCHER"
  echo "  Run authentication once: ~/.mcp-adaptor/bin/mcp-adaptor auth"
else
  echo ""
  echo "  mcp-adaptor launcher not found at $LAUNCHER"
  echo "  To install:"
  echo "  1. Open VS Code → Extensions → search 'Salesforce Internal DX'"
  echo "  2. Install the extension and open VS Code once to activate it"
  echo "  3. Run: ~/.mcp-adaptor/bin/mcp-adaptor auth"
fi

# ── 9. Build Gem index for user-rca-advisor ───────────────────────────────────
step "Checking user-rca-advisor Gem index"

RCA_INDEX="/tmp/revenue-cloud-advanced-architect-assistant/mcp-server/dist/index.js"
if [ -f "$RCA_INDEX" ]; then
  ok "user-rca-advisor server found"
else
  echo ""
  echo "  user-rca-advisor server not found."
  echo "  Clone and build it:"
  echo "    git clone git@git.soma.salesforce.com:pshantanu/revenue-cloud-advanced-architect-assistant /tmp/revenue-cloud-advanced-architect-assistant"
  echo "    cd /tmp/revenue-cloud-advanced-architect-assistant/mcp-server && npm install && npm run build"
fi

# ── 10. Generate initial dashboard ───────────────────────────────────────────
step "Generating Feature Journey Dashboard"

if [ -f "$ROOT/scripts/generate-journey.js" ] && [ -f "$ROOT/FEATURE_TRACKER.json" ]; then
  node "$ROOT/scripts/generate-journey.js"
  ok "Dashboard → results/feature-journey.html"
else
  skip "FEATURE_TRACKER.json or generate-journey.js not found — skipping"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}Team OS setup complete.${NC}"
echo ""
echo "  Next steps:"
echo "  1. Authenticate to your Salesforce org: sf org login web --alias rc-dev"
echo "  2. Authenticate mcp-adaptor (once):     ~/.mcp-adaptor/bin/mcp-adaptor auth"
echo "  3. Start Claude Code:                   claude"
echo "  4. Open the dashboard:                  open results/feature-journey.html"
echo ""
