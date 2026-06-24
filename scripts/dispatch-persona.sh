#!/usr/bin/env bash
# 특정 tmux 페인에 llm-config.yaml을 읽어 LLM CLI + 프롬프트 전송
# Usage: dispatch-persona.sh <session> <pane-id> "<topic>"

set -e
SESSION="$1"
PANE="$2"
TOPIC="$3"
SKILL_DIR="${SKILL_DIR:-E:/My-wiki/project/storm}"
CONFIG="$SKILL_DIR/llm-config.yaml"
OUTPUT_FILE="$SKILL_DIR/tmp/persona-$PANE.md"

# Windows의 python3는 MS Store 스텁일 수 있으므로 실제 실행 가능한 python 선택
PY="$(command -v python 2>/dev/null || command -v python3)"
[ -n "$PY" ] || { echo "❌ python3/python 없음" >&2; exit 1; }

if [ ! -f "$CONFIG" ]; then
  echo "❌ llm-config.yaml 없음: $CONFIG" >&2; exit 1
fi

# yaml에서 이 페인의 LLM + 페르소나 + role_desc 읽기 (| 구분자로 멀티워드 필드 보호)
IFS='|' read -r LLM PERSONA ROLE_DESC <<< "$("$PY" - <<EOF
import yaml, sys
cfg = yaml.safe_load(open("$CONFIG", encoding="utf-8"))
pane = cfg["panes"]["$PANE"]
role_desc = pane.get("role_desc", pane["persona"])
print(pane["llm"] + "|" + pane["persona"] + "|" + role_desc)
EOF
)"
# #4: set -e는 $(...) 할당에서 exit code를 전파하지 않으므로 명시적 가드
[ -n "$LLM" ] && [ -n "$PERSONA" ] || { echo "❌ yaml 파싱 실패 (LLM/페르소나 비어있음): $CONFIG" >&2; exit 1; }

# LLM CLI 명령 읽기 — 1차 LLM → pane_fallback 티어 → fallback_llm 순서로 확인 (#6, ADR-03)
LLM_CMD="$("$PY" - <<EOF
import yaml, sys, shutil
cfg = yaml.safe_load(open("$CONFIG", encoding="utf-8"))
llm = "$LLM"
pane = "$PANE"

# 비대화형(-p) 실행 불가 CLI는 설치돼 있어도 미설치처럼 취급 (ADR-03 보강)
unsupported = set(cfg.get("non_interactive_unsupported", []))

def resolve(name):
    if name in unsupported:
        return None
    cmd = cfg["llm_commands"].get(name, "")
    bin_name = cmd.split()[0] if cmd else ""
    return cmd if (cmd and shutil.which(bin_name)) else None

# 1차: 지정 LLM
cmd = resolve(llm)
if cmd:
    print(cmd); sys.exit(0)

# 2차: pane_fallback — Claude 티어 (ADR-03)
pane_fb = cfg.get("pane_fallback", {}).get(pane, "")
if pane_fb:
    cmd = resolve(pane_fb)
    if cmd:
        print(f"⚠️  {llm} not found → pane {pane} fallback: {pane_fb}", file=sys.stderr)
        print(cmd); sys.exit(0)

# 3차: 전역 fallback_llm
global_fb = cfg.get("fallback_llm", "claude-sonnet")
cmd = resolve(global_fb)
if cmd:
    print(f"⚠️  {llm} / {pane_fb or '-'} not found → global fallback: {global_fb}", file=sys.stderr)
    print(cmd); sys.exit(0)

print(f"❌ {llm}, pane_fallback({pane_fb or '-'}), global fallback({global_fb}) 모두 없음 — claude CLI 설치 확인 필요", file=sys.stderr)
sys.exit(1)
EOF
)"
# #4: LLM_CMD 빈 문자열도 명시적 가드
[ -n "$LLM_CMD" ] || { echo "❌ LLM 명령 확인 실패 (LLM: $LLM)" >&2; exit 1; }

# Step 1 프롬프트 변수 치환 — Python으로 처리 (sed 구분자 충돌 방지)
# 변수를 sys.argv로 전달해 |, &, \ 등 특수문자를 안전하게 치환한다.
# 영속 파일 사용 — mktemp+trap 금지 (dispatch 즉시 종료 시 tmux가 cat 전에 파일이 삭제됨)
PROMPT_FILE="$SKILL_DIR/tmp/prompt-$PANE.md"
"$PY" - \
    "$SKILL_DIR/sub-skills/step1-multi-perspective.md" \
    "$TOPIC" "$PERSONA" "$LLM" "$PANE" "$ROLE_DESC" \
    > "$PROMPT_FILE" <<'PYEOF'
import sys

template_path, topic, persona, llm, pane, role_desc = sys.argv[1:7]

with open(template_path, encoding="utf-8") as f:
    lines = f.readlines()

# YAML 프론트매터 제거: 두 번째 --- 이후부터 출력 (awk 동작과 동일)
dash_count = 0
body_lines = []
for line in lines:
    if line.rstrip("\n") == "---":
        dash_count += 1
        continue
    if dash_count >= 2:
        body_lines.append(line)

body = "".join(body_lines)
body = body.replace("{{TOPIC}}", topic)
body = body.replace("{{PERSONA}}", persona)
body = body.replace("{{ASSIGNED_LLM}}", llm)
body = body.replace("{{PANE_ID}}", pane)
body = body.replace("{{ROLE_DESC}}", role_desc)
print(body, end="")
PYEOF

# 페인에 명령 전송
CMD="$LLM_CMD \"\$(cat '$PROMPT_FILE')\" > '$OUTPUT_FILE' 2>&1 && echo '✅ [$PERSONA] 완료'"
tmux send-keys -t "$SESSION:0.$PANE" \
  "echo '🔍 [$PERSONA/$LLM] 리서치 시작...' && $CMD" Enter

echo "Dispatched: Pane $PANE → $LLM ($PERSONA)"
