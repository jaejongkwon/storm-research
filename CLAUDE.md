# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## 프로젝트 개요

Stanford STORM 방법론(Shao et al., NAACL 2024) 기반 딥 리서치 자동화 스킬.
5개 LLM 페르소나가 CMUX 멀티 페인에서 병렬 조사 → 4단계 파이프라인 → HTML + Wiki 노트 이중 출력.

트리거: `/storm-research [주제]` (Claude Code 슬래시 커맨드)

---

## 핵심 경로

저장소 루트(`E:\My-wiki\project\storm`)가 곧 스킬 디렉터리다. 전역 심링크가 이 루트로 직접 연결된다.

| 역할 | 경로 |
|------|------|
| 메인 스킬 | `E:\My-wiki\project\storm\SKILL.md` |
| LLM 설정 | `E:\My-wiki\project\storm\llm-config.yaml` |
| 4단계 프롬프트 | `E:\My-wiki\project\storm\sub-skills\` |
| 자동화 스크립트 | `E:\My-wiki\project\storm\scripts\` |
| HTML 템플릿 | `E:\My-wiki\project\storm\templates\` |
| 실행 임시 파일 | `E:\My-wiki\project\storm\tmp\` (gitignore) |
| HTML 출력 | `E:\My-wiki\project\storm\dist\<topic-slug>\report.html` |
| 작업 로그 (감사 추적) | `E:\My-wiki\project\storm\dist\<topic-slug>\logs\` |
| Wiki 출력 | `E:\My-wiki\wiki\AI-Strategy\<topic-slug>-storm.md` |
| 전역 심링크 | `C:\Users\KECC\.claude\skills\storm-research` → `E:\My-wiki\project\storm` (Windows Junction) |

---

## 실행 흐름

```
/storm-research [주제]
    │
    ├─ Phase 0:   tmp/ 초기화
    ├─ Phase 0.5: 리서치 계약 수립(crystallize) → tmp/research-contract.md
    │             + 실행 계획 사용자 승인 (유일한 승인 게이트 — 이후 YOLO)
    ├─ Phase 1:   llm-config.yaml 읽기 → 5개 CMUX 페인 생성 → 페르소나 디스패치
    │             scripts/setup-panes.sh + scripts/dispatch-persona.sh × 5
    ├─ Phase 2:   완료 대기 (scripts/collect-outputs.sh, 타임아웃 300초)
    │             → tmp/persona-1.md ~ persona-5.md
    │             → 관점별 압축본 tmp/step1-digests.md (Step 2·3에는 압축본만 전달)
    ├─ Phase 3:   메인 Opus가 Step 2~4 순차 실행
    │             → tmp/step2-contradictions.md
    │             → tmp/step3-synthesis.md
    │             → tmp/step4-peer-review.md (주장 등급: 확정/조건부/미확인 포함)
    ├─ Phase 3.5: export 전 self-check (자가 게이트 — 실패 항목 보완 후 재검사)
    ├─ Phase 4:   scripts/generate-html.py → dist/<slug>/report.html
    │             wiki 노트 → wiki/AI-Strategy/<slug>-storm.md
    └─ 완료 보고: tmp/ 산출물 → dist/<slug>/logs/ 아카이브 + 품질 메트릭 자가 보고
```

페인 간 직접 통신 없음. 모든 결과는 파일 경유 (`tmp/persona-N.md`).

---

## LLM 설정 변경

`llm-config.yaml`만 편집하면 됨 — 코드 수정 불필요.

```yaml
panes:
  "1":
    persona: Engineer
    llm: claude-sonnet   # 이 줄만 바꾸면 됨

llm_commands:
  claude-opus:   "claude --model claude-opus-4-8 -p"
  claude-sonnet: "claude --model claude-sonnet-4-6 -p"
  claude-haiku:  "claude --model claude-haiku-4-5 -p"
  codex:         "codex"
  antigravity:   "antigravity run"
  kimi:          "kimi chat"
  # 새 LLM 추가: 이 섹션에 한 줄 추가
```

지정 LLM CLI가 없으면 → `claude-sonnet` 자동 fallback + 경고 출력 후 계속 진행.

---

## 아키텍처 원칙

- **SKILL.md = 오케스트레이터 지시문**: Claude Code가 읽고 따르는 자연어 파이프라인 명세
- **sub-skills/ = 단계별 프롬프트 템플릿**: `{{TOPIC}}`, `{{STEP1_OUTPUT}}` 등 변수 치환 방식
- **scripts/ = 쉘 자동화**: SKILL.md의 지시를 실제 시스템 명령으로 수행
- **llm-config.yaml = 단일 설정 진입점**: LLM 교체 시 이 파일 외 어떤 파일도 수정 불필요

---

## 스크립트 사용법

```bash
# 페인 초기화
bash scripts/setup-panes.sh <session-name> "<주제>"

# 특정 페인에 페르소나 디스패치 (llm-config.yaml 자동 참조)
bash scripts/dispatch-persona.sh <session> <pane-id> "<주제>"

# 출력 수집 대기
bash scripts/collect-outputs.sh [skill-dir] [timeout-sec]

# HTML 보고서 생성 (Windows: python3는 Store 스텁일 수 있어 python 우선)
PY="$(command -v python 2>/dev/null || command -v python3)"
"$PY" scripts/generate-html.py "<주제>" \
  --step2 tmp/step2-contradictions.md \
  --step3 tmp/step3-synthesis.md \
  --step4 tmp/step4-peer-review.md
```

Python 의존성: `pip install pyyaml jinja2 markdown`

---

## Wiki 노트 규격

생성되는 `wiki/AI-Strategy/<slug>-storm.md` frontmatter:

```yaml
---
title: "<주제> STORM 리서치"
type: research
method: STORM
topic: "<주제>"
date: YYYY-MM-DD
llms: [claude-sonnet, codex, ...]  # 실제 사용된 LLM 목록
source: project/storm/dist/<slug>/report.html
---
```

본문: Step 3 종합 내용 ≤500자 압축 + 출처 목록. Vault lint 통과 필수.

---

## 비목표 (작업 범위 경계)

- 실시간 웹 크롤링 없음 — LLM 내장 지식만 활용
- 페르소나 역할 실행 중 변경 불가 — 실행 전 config 수정
- 클라우드 전송 없음 — 로컬 전용

---

## 관련 문서

- PRD: `project/storm/PRD.md`
- 구현 플랜: `docs/superpowers/plans/2026-06-22-storm-research-skill.md`
- 원문 스펙: `raw/스탠퍼드 STOM 기반 클로드 리서티 스킬 제작.md`
