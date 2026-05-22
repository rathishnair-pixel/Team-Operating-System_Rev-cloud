#!/usr/bin/env bash
# md-to-docx.sh — convert results/*.md to .docx with rendered Mermaid diagrams.
#
# Pipeline:
#   1. Pre-render every ```mermaid block in the .md to a PNG via mmdc
#   2. Rewrite the .md to replace each block with a Markdown image reference
#   3. Pipe that rewritten markdown through pandoc to produce .docx
#   4. Place the .docx next to the original .md in results/
#
# Usage:
#   scripts/md-to-docx.sh                       # process every .md in results/
#   scripts/md-to-docx.sh results/foo.md        # process a single file

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="$REPO_ROOT/results"
CACHE_DIR="$REPO_ROOT/.mermaid-cache"
MMDC="$REPO_ROOT/node_modules/.bin/mmdc"

command -v pandoc >/dev/null 2>&1 || {
  echo "error: pandoc not found. Install with: brew install pandoc" >&2
  exit 1
}
[[ -x "$MMDC" ]] || {
  echo "error: $MMDC not found. Install with: npm install --save-dev @mermaid-js/mermaid-cli" >&2
  exit 1
}

mkdir -p "$CACHE_DIR"

# Pick which files to convert.
if [[ $# -gt 0 ]]; then
  files=("$@")
else
  shopt -s nullglob
  files=("$RESULTS_DIR"/*.md)
  shopt -u nullglob
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No .md files to convert in $RESULTS_DIR." >&2
  exit 0
fi

# convert_one <md_path>
# Splits the .md, renders each ```mermaid block to PNG via mmdc, rewrites the
# block with an image reference, then pandoc → docx.
convert_one() {
  local md="$1"
  local stem
  stem="$(basename "$md" .md)"
  local docx="$RESULTS_DIR/$stem.docx"
  local rewritten="$CACHE_DIR/$stem.rewritten.md"
  local diag_idx=0

  # Use awk to extract mermaid blocks and emit a rewritten markdown stream.
  # Each block is written to $CACHE_DIR/<stem>-NNN.mmd; the rewritten markdown
  # references $CACHE_DIR/<stem>-NNN.png (which mmdc produces below).
  awk -v stem="$stem" -v cache="$CACHE_DIR" '
    BEGIN { in_mermaid = 0; idx = 0 }
    /^```mermaid[[:space:]]*$/ {
      in_mermaid = 1
      mmd = sprintf("%s/%s-%03d.mmd", cache, stem, idx)
      png_rel = sprintf(".mermaid-cache/%s-%03d.png", stem, idx)
      printf "" > mmd
      next
    }
    in_mermaid && /^```[[:space:]]*$/ {
      in_mermaid = 0
      printf "![Diagram %d](%s)\n", idx + 1, png_rel
      idx++
      next
    }
    in_mermaid {
      print >> mmd
      next
    }
    { print }
  ' "$md" > "$rewritten"

  # Render every captured .mmd to a .png at 1.5x scale for crispness.
  for mmd in "$CACHE_DIR/$stem"-*.mmd; do
    [[ -f "$mmd" ]] || continue
    local png="${mmd%.mmd}.png"
    if ! "$MMDC" -i "$mmd" -o "$png" --scale 1.5 --backgroundColor white >/dev/null 2>&1; then
      echo "  warn: mmdc failed for $mmd — skipping diagram" >&2
      # Replace the broken image ref with a fenced code block so the source still ships
      local idx_num
      idx_num="$(basename "$mmd" .mmd | sed -E "s/^${stem}-//")"
      local png_rel=".mermaid-cache/${stem}-${idx_num}.png"
      local fallback
      fallback="$(printf '\n```\n%s\n```\n' "$(cat "$mmd")")"
      # Inline replacement (BSD sed compatible)
      python3 - "$rewritten" "$png_rel" "$fallback" <<'PY'
import sys, pathlib
path, target, fallback = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path(path)
text = p.read_text()
needle = f"![Diagram"
# The simplest is to do a literal replacement of the image markdown
# pointing at the failed PNG path:
import re
text = re.sub(r"!\[Diagram \d+\]\(" + re.escape(target) + r"\)", fallback, text, count=1)
p.write_text(text)
PY
    fi
  done

  pandoc \
    --from=gfm \
    --to=docx \
    --resource-path="$REPO_ROOT" \
    --output="$docx" \
    "$rewritten"

  echo "✓ $(realpath --relative-to="$REPO_ROOT" "$docx" 2>/dev/null || echo "$docx")"
}

count=0
for md in "${files[@]}"; do
  if [[ ! -f "$md" ]]; then
    echo "  skip: $md not found" >&2
    continue
  fi
  convert_one "$md"
  count=$((count + 1))
done

echo
echo "Wrote $count .docx file(s) to $RESULTS_DIR"
