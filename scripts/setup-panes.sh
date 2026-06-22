#!/usr/bin/env bash
# STORM 5개 tmux 페인 초기화
# Usage: setup-panes.sh <session-name> "<topic>"

set -e
SESSION="${1:-storm}"
TOPIC="${2:-Research Topic}"
SKILL_DIR="${SKILL_DIR:-E:/My-wiki/project/storm}"
# 토픽에 작은따옴표가 있으면 tmux send-keys 명령이 깨짐 → 이스케이프
SAFE_TOPIC="${TOPIC//\'/\'\\\'\'}"

# 기존 세션 종료
tmux kill-session -t "$SESSION" 2>/dev/null || true

# 새 세션 생성 (pane 0 = 메인 오케스트레이터)
tmux new-session -d -s "$SESSION" -x 220 -y 50

# 5개 페인 추가
for i in 1 2 3 4 5; do
  tmux split-window -t "$SESSION:0" -v
  tmux select-layout -t "$SESSION:0" tiled
done

# 각 페인에 환경변수 주입
for i in 1 2 3 4 5; do
  tmux send-keys -t "$SESSION:0.$i" \
    "export STORM_PANE=$i STORM_TOPIC='$SAFE_TOPIC' STORM_DIR='$SKILL_DIR'" Enter
done

echo "✅ STORM session '$SESSION' 생성 완료 (pane 0: 오케스트레이터, 1-5: 페르소나)"
