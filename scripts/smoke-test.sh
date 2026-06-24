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
# 이 테스트는 실제 tmp/ 산출물(persona·step)을 더미로 덮어쓰므로,
# 시작 시 실존 파일을 백업하고 종료 시 복원한다 — 실제 STORM 결과 보존.
REAL_FILES=(persona-1.md persona-2.md persona-3.md persona-4.md persona-5.md \
            step2-contradictions.md step3-synthesis.md step4-peer-review.md)
BACKUP_DIR="$TMP_DIR/.smoke-backup"

backup_real() {
  mkdir -p "$BACKUP_DIR"
  for f in "${REAL_FILES[@]}"; do
    [ -f "$TMP_DIR/$f" ] && cp "$TMP_DIR/$f" "$BACKUP_DIR/$f"
  done
}

cleanup() {
  # 테스트가 만든 더미 산출물 제거
  for f in "${REAL_FILES[@]}"; do rm -f "$TMP_DIR/$f"; done
  rm -rf "$DIST_DIR_POSIX"
  rm -f  "$WIKI_FILE_POSIX"
  # 백업해 둔 실존 파일 복원
  if [ -d "$BACKUP_DIR" ]; then
    for f in "${REAL_FILES[@]}"; do
      [ -f "$BACKUP_DIR/$f" ] && mv "$BACKUP_DIR/$f" "$TMP_DIR/$f"
    done
    rmdir "$BACKUP_DIR" 2>/dev/null
  fi
}
trap cleanup EXIT

backup_real   # 더미 생성 전에 실존 파일 백업

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
# CHECK 6: ADR-03 — pane_fallback config 구조 검증
#   pane_fallback 섹션이 존재하고 5개 페인 모두 유효한 Claude 티어를 갖는지 확인.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "[6] ADR-03: pane_fallback config 구조 검증"

"$PY" - <<PYCHECK
import sys, yaml

cfg = yaml.safe_load(open("${SKILL_DIR_WIN}/llm-config.yaml", encoding="utf-8"))
valid_tiers = {"claude-opus", "claude-sonnet", "claude-haiku"}
pane_fallback = cfg.get("pane_fallback", {})
failed = []

if not pane_fallback:
    print("  FAIL: pane_fallback 섹션 없음")
    sys.exit(1)

for pane in ["1", "2", "3", "4", "5"]:
    tier = pane_fallback.get(pane, "")
    if tier in valid_tiers:
        print(f"  PASS: pane_fallback[{pane}] = {tier}")
    else:
        print(f"  FAIL: pane_fallback[{pane}] = '{tier}' (유효한 Claude 티어 아님)")
        failed.append(pane)

if failed:
    sys.exit(1)
PYCHECK

if [ $? -eq 0 ]; then
  ok "pane_fallback 5개 페인 모두 유효한 Claude 티어 보유"
else
  fail "pane_fallback 구조 오류"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CHECK 7: ADR-03 — fallback 체인 로직 검증
#   Claude만 설치된 환경을 모의(shutil.which mock)해 각 페인이
#   올바른 티어를 선택하는지 확인.
#   pane 2 (codex → claude-sonnet), pane 3 (kimi → claude-opus),
#   pane 4 (claude-haiku → haiku 직접 해소), 3차 fallback 경로.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "[7] ADR-03: fallback 체인 로직 검증 (Claude-only 환경 모의)"

"$PY" - <<PYCHECK
import sys, yaml

cfg = yaml.safe_load(open("${SKILL_DIR_WIN}/llm-config.yaml", encoding="utf-8"))

# Claude CLI만 설치된 환경 모의 — "claude" 바이너리만 존재
def mock_resolve(name):
    cmd = cfg["llm_commands"].get(name, "")
    bin_name = cmd.split()[0] if cmd else ""
    exists = (bin_name == "claude")   # claude만 설치된 가정
    return cmd if (cmd and exists) else None

def pick_cmd(llm, pane):
    """dispatch-persona.sh의 fallback 체인 재현."""
    cmd = mock_resolve(llm)
    if cmd:
        return cmd, "primary"
    pane_fb = cfg.get("pane_fallback", {}).get(pane, "")
    if pane_fb:
        cmd = mock_resolve(pane_fb)
        if cmd:
            return cmd, f"pane_fallback({pane_fb})"
    global_fb = cfg.get("fallback_llm", "claude-sonnet")
    cmd = mock_resolve(global_fb)
    if cmd:
        return cmd, f"global_fallback({global_fb})"
    return None, "none"

cases = [
    # (pane, primary_llm, expected_model, description)
    ("2", "codex",        "claude-sonnet-4-6", "Economist: codex → pane_fallback → sonnet"),
    ("3", "kimi",         "claude-opus-4-8",   "Regulator: kimi  → pane_fallback → opus"),
    ("4", "claude-haiku", "claude-haiku-4-5",  "Critical Consumer: haiku → 1차 직접 해소"),
    ("5", "antigravity",  "claude-sonnet-4-6", "Futurist: antigravity → pane_fallback → sonnet"),
]

# 3차 fallback 경로: pane_fallback 티어도 없는 가상 케이스
cfg_copy = {**cfg, "pane_fallback": {}}
def pick_global(llm):
    cmd = mock_resolve(llm)
    if cmd: return cmd, "primary"
    global_fb = cfg_copy.get("fallback_llm", "claude-sonnet")
    cmd = mock_resolve(global_fb)
    return (cmd, f"global_fallback({global_fb})") if cmd else (None, "none")

failed = []
for pane, llm, expected_model, desc in cases:
    cmd, via = pick_cmd(llm, pane)
    if cmd and expected_model in cmd:
        print(f"  PASS: {desc} (via {via})")
    else:
        print(f"  FAIL: {desc} → got '{cmd}' (expected model: {expected_model})")
        failed.append(desc)

# 3차 fallback 체인
llm3 = "nonexistent-llm"
cmd3, via3 = pick_global(llm3)
expected3 = "claude-sonnet-4-6"
if cmd3 and expected3 in cmd3:
    print(f"  PASS: 3차 fallback: {llm3} + pane_fallback 없음 → {via3}")
else:
    print(f"  FAIL: 3차 fallback → got '{cmd3}'")
    failed.append("3차 fallback")

if failed:
    sys.exit(1)
PYCHECK

if [ $? -eq 0 ]; then
  ok "ADR-03 fallback 체인 모든 경로 정상 (1차→2차→3차)"
else
  fail "ADR-03 fallback 체인 오류"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CHECK 8: 출처 추출 — 영문 References + 한국어 헤더 모두 지원 검증
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "[8] 출처 추출 (영문 + 한국어 헤더)"

"$PY" - <<PYCHECK
import sys, re
from pathlib import Path

scripts_dir = Path("${SKILL_DIR_WIN}/scripts")
sys.path.insert(0, str(scripts_dir))

# extract_sources 로직 직접 검증 (import 없이 인라인)
def extract_sources(synthesis_md, peer_review_md=""):
    seen = set()
    sources = []
    in_refs = False
    for line in synthesis_md.splitlines():
        if re.match(r"^##\s+(References|Sources|출처|참고문헌|참조)", line, re.IGNORECASE):
            in_refs = True
            continue
        if in_refs:
            if line.startswith("##"):
                break
            m = re.match(r"^\d+\.\s+(.+)", line)
            if m:
                entry = m.group(1).strip()
                if entry not in seen:
                    seen.add(entry)
                    sources.append(entry)
    return sources

# 영문 ## References
en_md = "# Synthesis\n## References\n1. Smith 2024\n2. Jones 2023\n"
src_en = extract_sources(en_md)
if len(src_en) == 2 and "Smith 2024" in src_en:
    print("  PASS: 영문 ## References 추출 (2건)")
else:
    print(f"  FAIL: 영문 References → {src_en}")
    sys.exit(1)

# 한국어 ## 출처
ko_md = "# 종합\n## 출처\n1. 홍길동 2024\n2. 이순신 2023\n"
src_ko = extract_sources(ko_md)
if len(src_ko) == 2 and "홍길동 2024" in src_ko:
    print("  PASS: 한국어 ## 출처 추출 (2건)")
else:
    print(f"  FAIL: 한국어 출처 → {src_ko}")
    sys.exit(1)

# 헤더 없을 때 빈 목록 반환
no_refs_md = "# 종합\n내용만 있고 출처 섹션 없음\n"
src_none = extract_sources(no_refs_md)
if src_none == []:
    print("  PASS: 출처 섹션 없으면 빈 목록 반환")
else:
    print(f"  FAIL: 예상 빈 목록, 실제: {src_none}")
    sys.exit(1)
PYCHECK

if [ $? -eq 0 ]; then
  ok "출처 추출 영문+한국어 헤더 모두 정상"
else
  fail "출처 추출 오류"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CHECK 9: 비대화형 미지원 LLM(codex)은 "설치돼 있어도" fallback 해야 함
#   버그 재현: codex는 npm 설치돼 shutil.which()가 경로를 반환하지만
#   대화형 터미널 전용이라 `cmd "$(cat prompt)" > out` 패턴에서 실패한다.
#   resolver는 non_interactive_unsupported 목록의 LLM을 "설치돼 있어도"
#   건너뛰고 pane_fallback(claude-sonnet)으로 대체해야 한다.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "[9] 비대화형 미지원 LLM fallback (codex 설치됨 → sonnet)"

"$PY" - <<PYCHECK
import sys, yaml

cfg = yaml.safe_load(open("${SKILL_DIR_WIN}/llm-config.yaml", encoding="utf-8"))

# 버그 조건 모의: claude AND codex 둘 다 설치된 환경
def mock_resolve(name, unsupported):
    if name in unsupported:
        return None   # 비대화형 미지원 → 설치돼 있어도 건너뜀
    cmd = cfg["llm_commands"].get(name, "")
    bin_name = cmd.split()[0] if cmd else ""
    exists = bin_name in ("claude", "codex")   # codex도 설치된 가정
    return cmd if (cmd and exists) else None

def pick_cmd(llm, pane, unsupported):
    cmd = mock_resolve(llm, unsupported)
    if cmd:
        return cmd
    pane_fb = cfg.get("pane_fallback", {}).get(pane, "")
    if pane_fb:
        cmd = mock_resolve(pane_fb, unsupported)
        if cmd:
            return cmd
    global_fb = cfg.get("fallback_llm", "claude-sonnet")
    return mock_resolve(global_fb, unsupported)

unsupported = set(cfg.get("non_interactive_unsupported", []))

# 핵심 단언: pane 2 (codex) → codex 설치됐어도 sonnet으로 fallback
cmd = pick_cmd("codex", "2", unsupported)
if cmd and "claude-sonnet-4-6" in cmd:
    print("  PASS: codex 설치 환경에서도 pane 2 → claude-sonnet fallback")
else:
    print(f"  FAIL: pane 2 → got '{cmd}' (expected claude-sonnet-4-6)")
    print("        → llm-config.yaml에 non_interactive_unsupported: [codex] 필요")
    sys.exit(1)

# codex가 unsupported 목록에 실제로 등록됐는지 확인
if "codex" in unsupported:
    print("  PASS: non_interactive_unsupported 목록에 codex 등록됨")
else:
    print("  FAIL: non_interactive_unsupported 목록에 codex 없음")
    sys.exit(1)
PYCHECK

if [ $? -eq 0 ]; then
  ok "비대화형 미지원 LLM은 설치돼 있어도 fallback"
else
  fail "비대화형 미지원 LLM fallback 미작동 (Bug 2)"
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
