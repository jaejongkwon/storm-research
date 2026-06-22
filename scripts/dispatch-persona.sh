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

if [ ! -f "$CONFIG" ]; then
  echo "❌ llm-config.yaml 없음: $CONFIG" >&2; exit 1
fi

# yaml에서 이 페인의 LLM + 페르소나 읽기 (| 구분자로 멀티워드 페르소나 보호)
IFS='|' read -r LLM PERSONA <<< "$(python3 - <<EOF
import yaml, sys
cfg = yaml.safe_load(open("$CONFIG", encoding="utf-8"))
pane = cfg["panes"]["$PANE"]
print(pane["llm"] + "|" + pane["persona"])
EOF
)"
# #4: set -e는 $(...) 할당에서 exit code를 전파하지 않으므로 명시적 가드
[ -n "$LLM" ] && [ -n "$PERSONA" ] || { echo "❌ yaml 파싱 실패 (LLM/페르소나 비어있음): $CONFIG" >&2; exit 1; }

# LLM CLI 명령 읽기 — 1차 LLM + fallback 바이너리 모두 존재 확인 (#6)
LLM_CMD="$(python3 - <<EOF
import yaml, sys, shutil
cfg = yaml.safe_load(open("$CONFIG", encoding="utf-8"))
llm = "$LLM"
cmd = cfg["llm_commands"].get(llm, "")
bin_name = cmd.split()[0] if cmd else ""
if not cmd or not shutil.which(bin_name):
    fallback = cfg.get("fallback_llm", "claude-sonnet")
    fallback_cmd = cfg["llm_commands"].get(fallback, "")
    fallback_bin = fallback_cmd.split()[0] if fallback_cmd else ""
    if not fallback_cmd or not shutil.which(fallback_bin):
        print(f"❌ {llm} 와 fallback {fallback} 모두 없음 — claude CLI 설치 확인 필요", file=sys.stderr)
        sys.exit(1)
    print(f"⚠️  {llm} ({bin_name or '?'}) not found → {fallback}", file=sys.stderr)
    cmd = fallback_cmd
print(cmd)
EOF
)"
# #4: LLM_CMD 빈 문자열도 명시적 가드
[ -n "$LLM_CMD" ] || { echo "❌ LLM 명령 확인 실패 (LLM: $LLM)" >&2; exit 1; }

# Step 1 프롬프트 변수 치환 — Python으로 처리 (sed 구분자 충돌 방지)
# 변수를 sys.argv로 전달해 |, &, \ 등 특수문자를 안전하게 치환한다.
# 영속 파일 사용 — mktemp+trap 금지 (dispatch 즉시 종료 시 tmux가 cat 전에 파일이 삭제됨)
PROMPT_FILE="$SKILL_DIR/tmp/prompt-$PANE.md"
python3 - \
    "$SKILL_DIR/sub-skills/step1-multi-perspective.md" \
    "$TOPIC" "$PERSONA" "$LLM" "$PANE" \
    > "$PROMPT_FILE" <<'PYEOF'
import sys

template_path, topic, persona, llm, pane = sys.argv[1:6]

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
print(body, end="")
PYEOF

# 페인에 명령 전송
CMD="$LLM_CMD \"\$(cat '$PROMPT_FILE')\" > '$OUTPUT_FILE' 2>&1 && echo '✅ [$PERSONA] 완료'"
tmux send-keys -t "$SESSION:0.$PANE" \
  "echo '🔍 [$PERSONA/$LLM] 리서치 시작...' && $CMD" Enter

echo "Dispatched: Pane $PANE → $LLM ($PERSONA)"
