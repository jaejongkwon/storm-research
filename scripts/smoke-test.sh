#!/usr/bin/env bash
# STORM Research Skill — Integration Smoke Test
# Tests the full pipeline with dummy data (no live LLM calls, no tmux).
# Usage: bash scripts/smoke-test.sh   (run from skill root or anywhere)
# Exit 0: all checks passed; Exit 1: at least one check failed.
set -e

# ── Path resolution ────────────────────────────────────────────────────────────
# POSIX path for bash (file tests, rm, etc.)
SKILL_DIR_POSIX="$(cd "$(dirname "$0")/.." && pwd)"
# Windows path for Python: /e/My-wiki → e:/My-wiki  (Python accepts lowercase drive)
SKILL_DIR_WIN="$(echo "$SKILL_DIR_POSIX" | sed 's|^/\([a-z]\)/|\1:/|')"

TMP_DIR="$SKILL_DIR_POSIX/tmp"
SLUG="bim-자동화-테스트"
DIST_DIR_POSIX="/e/My-wiki/project/storm/dist/$SLUG"
DIST_DIR_WIN="e:/My-wiki/project/storm/dist/$SLUG"
WIKI_FILE_POSIX="/e/My-wiki/wiki/AI-Strategy/${SLUG}-storm.md"
WIKI_FILE_WIN="e:/My-wiki/wiki/AI-Strategy/${SLUG}-storm.md"

# Resolve which Python has the deps (avoid Windows Store stub)
PY="python"

PASS=0
FAIL=0

ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

# ── Cleanup on exit ────────────────────────────────────────────────────────────
cleanup() {
  rm -f "$TMP_DIR/persona-"{1,2,3,4,5}".md" \
        "$TMP_DIR/step2-contradictions.md" \
        "$TMP_DIR/step3-synthesis.md" \
        "$TMP_DIR/step4-peer-review.md"
  rm -rf "$DIST_DIR_POSIX"
  rm -f  "$WIKI_FILE_POSIX"
}
trap cleanup EXIT

echo "========================================================"
echo " STORM smoke test"
echo " skill-dir: $SKILL_DIR_WIN"
echo "========================================================"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CHECK 1: ADR-01 — llm-config.yaml pane "3" persona = "Regulator"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "[1] ADR-01: pane 3 persona assertion"

PANE3_PERSONA="$($PY -c "
import yaml
with open('${SKILL_DIR_WIN}/llm-config.yaml', encoding='utf-8') as f:
    cfg = yaml.safe_load(f)
print(cfg['panes']['3']['persona'])
")"

if [ "$PANE3_PERSONA" = "Regulator" ]; then
  ok "pane 3 persona is 'Regulator'"
else
  fail "pane 3 persona is '$PANE3_PERSONA' (expected 'Regulator')"
fi

if [ "$PANE3_PERSONA" = "Historian" ]; then
  fail "pane 3 persona must NOT be 'Historian'"
else
  ok "pane 3 persona is not 'Historian'"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CHECK 2: slugify("BIM 자동화 테스트") → "bim-자동화-테스트"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "[2] slugify function"

SLUG_RESULT="$($PY -c "
import re
def slugify(topic):
    s = topic.lower()
    s = re.sub(r'[^\w\s-]', '', s)
    s = re.sub(r'[\s-]+', '-', s)
    return s.strip('-')
print(slugify('BIM 자동화 테스트'))
")"

EXPECTED_SLUG="bim-자동화-테스트"
if [ "$SLUG_RESULT" = "$EXPECTED_SLUG" ]; then
  ok "slugify('BIM 자동화 테스트') = '$SLUG_RESULT'"
else
  fail "slugify returned '$SLUG_RESULT' (expected '$EXPECTED_SLUG')"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CHECK 3 & 4: HTML generation + Wiki note
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "[3/4] Generating dummy tmp files..."

# Dummy persona files
for i in 1 2 3 4 5; do
  printf "## Pane %s dummy output\n- Analysis point\n- [Source %s, 2024]\n" "$i" "$i" \
    > "$TMP_DIR/persona-$i.md"
done

# Dummy step files
printf "# Contradictions\n- Engineer vs Regulator: standard application differs\n" \
  > "$TMP_DIR/step2-contradictions.md"
printf "# Synthesis\n## Executive Summary\nDummy synthesis content for BIM 자동화 테스트.\n" \
  > "$TMP_DIR/step3-synthesis.md"
printf "# Peer Review\n**Assessment:** Acceptable\n**Final Verdict:** 발행 적합.\n" \
  > "$TMP_DIR/step4-peer-review.md"

echo "  Running generate-html.py..."
"$PY" "${SKILL_DIR_WIN}/scripts/generate-html.py" \
  "BIM 자동화 테스트" \
  --step2 "${SKILL_DIR_WIN}/tmp/step2-contradictions.md" \
  --step3 "${SKILL_DIR_WIN}/tmp/step3-synthesis.md" \
  --step4 "${SKILL_DIR_WIN}/tmp/step4-peer-review.md"

# ─── CHECK 3: HTML file ────────────────────────────────────────────────────────
echo ""
echo "[3] HTML file content checks"

if [ -f "$DIST_DIR_POSIX/report.html" ]; then
  ok "report.html exists"
else
  fail "report.html NOT found at $DIST_DIR_WIN/report.html"
fi

"$PY" - <<PYCHECK
import sys
from pathlib import Path

html_path = Path("${DIST_DIR_WIN}/report.html")
if not html_path.exists():
    print("  SKIP: HTML file missing -- cannot check content")
    sys.exit(1)

html = html_path.read_text(encoding="utf-8")

checks = {
    "title-contains-topic":    "BIM 자동화 테스트" in html,
    "Contradictions-section":  "Contradictions" in html,
    "Synthesis-section":       "Synthesis" in html,
    "Peer-Review-section":     "Peer Review" in html,
    "Regulator-persona-badge": "Regulator" in html,
    "no-Historian-badge":      "Historian" not in html,
    "llm-badge-claude-sonnet": "claude-sonnet" in html,
}

failed = []
for name, result in checks.items():
    if result:
        print(f"  PASS: html-check: {name}")
    else:
        print(f"  FAIL: html-check: {name}")
        failed.append(name)

if failed:
    sys.exit(1)
PYCHECK

# ─── CHECK 4: Wiki note ────────────────────────────────────────────────────────
echo ""
echo "[4] Wiki note frontmatter checks"

if [ -f "$WIKI_FILE_POSIX" ]; then
  ok "wiki note exists"
else
  fail "wiki note NOT found at $WIKI_FILE_WIN"
fi

"$PY" - <<PYCHECK
import sys
from pathlib import Path

wiki_path = Path("${WIKI_FILE_WIN}")
if not wiki_path.exists():
    print("  SKIP: wiki file missing -- cannot check frontmatter")
    sys.exit(1)

content = wiki_path.read_text(encoding="utf-8")

required_fields = ["title", "type", "method", "topic", "date", "llms", "source"]
failed = []
for field in required_fields:
    if f"{field}:" in content:
        print(f"  PASS: wiki-frontmatter: {field}")
    else:
        print(f"  FAIL: wiki-frontmatter: {field} missing")
        failed.append(field)

if failed:
    sys.exit(1)
PYCHECK

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CHECK 5: collect-outputs.sh abort path (timeout=1, no persona files)
#
# Strategy: stub dispatch-persona.sh so the ADR-02 redispatch loop
# succeeds without tmux, but still leaves <3 persona files so the
# final count check triggers exit 1.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "[5] collect-outputs.sh abort path (no persona files, timeout=1)"

# Install no-op dispatch stub so the redispatch loop doesn't error
STUB="$SKILL_DIR_POSIX/scripts/dispatch-persona.sh.bak"
cp "$SKILL_DIR_POSIX/scripts/dispatch-persona.sh" "$STUB"
cat > "$SKILL_DIR_POSIX/scripts/dispatch-persona.sh" <<'STUB_SCRIPT'
#!/usr/bin/env bash
# smoke-test stub: no-op redispatch (no tmux available in CI)
exit 0
STUB_SCRIPT

# Remove persona files so count_done() returns 0 (< 3)
rm -f "$TMP_DIR/persona-"{1,2,3,4,5}".md"

# Run in subshell so outer set -e doesn't fire on expected exit 1
set +e
bash "$SKILL_DIR_POSIX/scripts/collect-outputs.sh" \
  "$SKILL_DIR_POSIX" "dummy-session" "dummy-topic" 1 > /dev/null 2>&1
COLLECT_EXIT=$?
set -e

# Restore real dispatch-persona.sh
mv "$STUB" "$SKILL_DIR_POSIX/scripts/dispatch-persona.sh"

if [ "$COLLECT_EXIT" -eq 1 ]; then
  ok "collect-outputs.sh exits 1 when <3 persona files (abort path confirmed)"
else
  fail "collect-outputs.sh exit code was $COLLECT_EXIT (expected 1)"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FINAL RESULT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "========================================================"
echo " Results: $PASS passed, $FAIL failed"
echo "========================================================"

if [ "$FAIL" -eq 0 ]; then
  echo "STORM smoke test: ALL CHECKS PASSED"
  exit 0
else
  echo "STORM smoke test: $FAIL CHECK(S) FAILED"
  exit 1
fi
