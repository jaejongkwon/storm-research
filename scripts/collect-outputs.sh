#!/usr/bin/env bash
set -e
# 5개 페인 출력 수집 대기 — ADR-02: 재시도(dispatch-persona.sh) + 최소 완료 기준 3개
# Usage: collect-outputs.sh <skill-dir> <session> <topic> [timeout-sec]
# Exit 0: 완료 ≥3 (계속 진행); Exit 1: 완료 <3 (파이프라인 중단)

SKILL_DIR="${1:?ERROR: skill-dir 필수}"
export SKILL_DIR
SESSION="${2:?ERROR: session 필수}"
TOPIC="${3:?ERROR: topic 필수}"
TIMEOUT="${4:-300}"
TMP_DIR="$SKILL_DIR/tmp"

[ -d "$TMP_DIR" ] || { echo "ERROR: tmp 디렉터리 없음: $TMP_DIR" >&2; exit 1; }

# #5: -s(비어있지 않음)만으론 LLM CLI 에러 텍스트와 실제 연구 출력을 구분 못 함
#     ≥5줄 기준으로 단순 에러 메시지("Error: unknown model\n...")를 제외
persona_ok() {
  local f="$TMP_DIR/persona-$1.md"
  [ -f "$f" ] && [ "$(wc -l < "$f" 2>/dev/null || echo 0)" -ge 5 ]
}

count_done() {
  local n=0
  for i in 1 2 3 4 5; do
    persona_ok "$i" && n=$((n+1))
  done
  echo "$n"
}

# #10: count_done을 매 반복 1회만 호출해 조건·echo 불일치 방지
# sleep 간격은 limit에 비례해 조절 (짧은 timeout에서 불필요한 대기 방지)
wait_loop() {
  local limit=$1 label=$2 elapsed=0 n sleep_sec
  while true; do
    n=$(count_done)
    [ "$n" -ge 5 ] && break
    [ "$elapsed" -ge "$limit" ] && break
    echo "  [$label] 진행: $n/5 완료 (${elapsed}s/${limit}s)"
    sleep_sec=$(( (limit - elapsed) > 5 ? 5 : (limit - elapsed) ))
    [ "$sleep_sec" -le 0 ] && sleep_sec=1
    sleep "$sleep_sec"
    elapsed=$((elapsed + sleep_sec))
  done
}

echo "⏳ Phase 1: 최대 ${TIMEOUT}s 대기..."
wait_loop "$TIMEOUT" "Phase1"

DONE=$(count_done)
if [ "$DONE" -eq 5 ]; then
  echo "✅ 모든 페르소나 완료 (5/5)"
  exit 0
fi

# ADR-02: 미완료 페인 재디스패치 후 +120s 대기
echo "⚠️  ${DONE}/5 완료. ADR-02: 미완료 페인 재디스패치 중..."
for i in 1 2 3 4 5; do
  if ! persona_ok "$i"; then
    echo "  🔁 Pane $i 재디스패치..."
    # #7: 실패 시 조용히 삼키지 않고 경고 출력 (CLAUDE.md §5 조용한 실패 금지)
    if ! bash "$SKILL_DIR/scripts/dispatch-persona.sh" "$SESSION" "$i" "$TOPIC"; then
      echo "  ⚠️ Pane $i 재디스패치 실패 — dispatch-persona.sh 오류 확인 필요" >&2
    fi
  fi
done

RETRY_TIMEOUT=$(( TIMEOUT < 60 ? TIMEOUT : 120 ))
echo "⏳ Phase 2 (Retry): +${RETRY_TIMEOUT}s 대기..."
wait_loop "$RETRY_TIMEOUT" "Retry"

DONE=$(count_done)
if [ "$DONE" -ge 3 ]; then
  echo "⚠️  최소 완료 기준 충족 (${DONE}/5) — 경고 후 계속 진행"
  for i in 1 2 3 4 5; do
    if ! persona_ok "$i"; then
      echo "  ⏰ Pane $i: 응답 없음 → HTML에 '⚠️ 응답 없음' 카드로 표시"
    fi
  done
  exit 0
fi

echo "❌ 최소 완료 기준 미달 (${DONE}/5 < 3) — 파이프라인 중단"
echo "   tmp/ 파일 보존됨. 개별 페인 결과 확인 후 수동 재실행 가능"
exit 1
