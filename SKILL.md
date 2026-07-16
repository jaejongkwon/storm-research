---
name: storm-research
description: |
  Stanford STORM 방법론 기반 딥 리서치 스킬.
  5개 LLM 페르소나를 tmux 멀티 페인에서 병렬 실행 → 4단계 파이프라인 → HTML + Wiki 노트 생성.

  트리거: /storm-research [주제]
  예시: /storm-research "ISO 19650 BIM 최신 동향"
  비-트리거: 단순 Q&A, 실시간 웹 크롤링이 필요한 경우, 1~2문장으로 답할 수 있는 질문.
---

# STORM Research Skill — Main Orchestrator

사용자가 `/storm-research [주제]`를 실행하면 이 스킬이 활성화된다.

**당신은 Main Opus 오케스트레이터다.** 아래 Phase를 순서대로 실행하라.
서브에이전트 위임 금지 — 모든 단계를 이 세션에서 직접 처리한다.

### ⚡ YOLO 실행 계약 (Phase 0.5 승인 후 — 절대 규칙)

Phase 0.5에서 사용자가 `y`로 승인하면, **그 순간부터 완료 보고까지 단 한 번도 멈추지 않는다.**
이것은 이 스킬의 가장 강한 규칙이며, 아래 단계 설명의 어떤 표현보다 우선한다.

- ⛔ Phase·Step 사이에서 사용자에게 **무엇도 묻지 않는다** — `AskUserQuestion` 호출 금지,
  "다음으로 진행할까요?"·"승인해 주세요"류 확인 금지, 중간 산출물을 보고한 뒤 응답을 기다리는 것 금지.
- ⛔ 각 Phase의 **"통과 조건"은 오케스트레이터가 스스로 판정하는 자가 게이트**다 —
  사용자 승인을 받는 게이트가 **아니다.** 조건이 충족되면 즉시 다음 단계로 넘어간다.
- ✅ Phase 1 → 2(수집+압축본) → 3(**Step 2 → 3 → 4 연속**) → 3.5(self-check) → 4 → 완료 보고를
  **하나의 끊김 없는 실행**으로 처리한다.
  각 Step·Phase가 끝나면 멈추지 말고 곧바로 다음을 시작한다.
- 🛑 사용자에게 멈춰도 되는 **유일한 예외 2가지**(둘 다 실패 분기뿐):
  1. Phase 2에서 완료 페인 < 3개 (EXIT_CODE=1)
  2. Phase 4 동료 심사 결과가 `Major Revision`
  이 둘 외에는 **어떤 이유로도** 멈추거나 묻지 않는다. (`Needs Revision`도 멈추지 않고 자동 수정 후 진행.)

**컨텍스트 압축 생존:** 재개 시 **가장 먼저** `tmp/.yolo-approved` 존재를 확인하라. 있으면 이미 승인된
실행이므로 재확인 없이 미완료 Phase(완료된 `tmp/` 산출물로 지점 판단)부터 위 계약대로 이어간다.
없으면 신규 실행이다. 완료 보고 출력 후 이 마커를 삭제한다.

---

## 변수 정의

슬래시 커맨드 인자에서 추출하여 아래 변수를 설정하라.

```
TOPIC     = <사용자 입력 주제 — 예: "ISO 19650 BIM 최신 동향">
SKILL_DIR = E:/My-wiki/project/storm
SLUG      = slugify(TOPIC)
            # topic.lower() → 특수문자(비\w) 제거 → 공백·하이픈을 단일 하이픈으로 → strip
            # Python \w는 유니코드 포함 → 한글 보존됨
            # 예: "ISO 19650 BIM 최신 동향" → "iso-19650-bim-최신-동향"
SESSION   = storm-<SLUG>
            # 예: "storm-iso-19650-bim"
```

---

## Phase 0: 준비 — tmp/ 초기화

기존 실행 잔여물을 모두 삭제하여 깨끗한 상태로 시작한다.

```bash
SKILL_DIR="E:/My-wiki/project/storm"
rm -f "$SKILL_DIR/tmp/persona-1.md" \
      "$SKILL_DIR/tmp/persona-2.md" \
      "$SKILL_DIR/tmp/persona-3.md" \
      "$SKILL_DIR/tmp/persona-4.md" \
      "$SKILL_DIR/tmp/persona-5.md" \
      "$SKILL_DIR/tmp/prompt-1.md" \
      "$SKILL_DIR/tmp/prompt-2.md" \
      "$SKILL_DIR/tmp/prompt-3.md" \
      "$SKILL_DIR/tmp/prompt-4.md" \
      "$SKILL_DIR/tmp/prompt-5.md" \
      "$SKILL_DIR/tmp/persona-1-digest.md" \
      "$SKILL_DIR/tmp/persona-2-digest.md" \
      "$SKILL_DIR/tmp/persona-3-digest.md" \
      "$SKILL_DIR/tmp/persona-4-digest.md" \
      "$SKILL_DIR/tmp/persona-5-digest.md" \
      "$SKILL_DIR/tmp/research-contract.md" \
      "$SKILL_DIR/tmp/step1-all-perspectives.md" \
      "$SKILL_DIR/tmp/step1-digests.md" \
      "$SKILL_DIR/tmp/step2-contradictions.md" \
      "$SKILL_DIR/tmp/step3-synthesis.md" \
      "$SKILL_DIR/tmp/step4-peer-review.md" \
      "$SKILL_DIR/tmp/.yolo-approved"
```

통과 조건: tmp/ 잔여 파일 삭제 완료 — Phase 1로 진행.

삭제 완료 후 Phase 0.5로 진행한다.

---

## Phase 0.5: 실행 계획 확인 — 사용자 승인 게이트

**이 단계에서 반드시 멈추고 사용자 승인을 받은 후에만 Phase 1로 진행한다.**

통과 조건: 사용자가 `y`(승인) 입력 시에만 Phase 1로 진행. `n`(취소)이면 STOP — awaiting gate verdict.

### 0.5-0. 리서치 계약 수립 (crystallize)

주제를 분석하여 **리서치 계약**을 확정한다. 계약은 이후 모든 단계와 Phase 3.5 self-check의
판정 기준이며, 승인 후에는 수정하지 않는다 (불변 seed).

1. **모호성 판정**: 주제가 다의적이거나(동명 프로젝트·용어 다의성 등) 범위·성공 기준이
   불명확하면, 사용자에게 질문을 **하나씩 순차로** 최대 3개(핵심 질문 / 범위·제외 대상 /
   성공 기준) 물어 해소한다. 주제가 명확하면 질문 없이 오케스트레이터가 직접 계약을 도출한다.
   (이 질문은 Phase 0.5 승인 이전이므로 YOLO 계약 위반이 아니다 — 승인 후에는 불가.)
2. **계약 저장**: 아래 형식으로 `tmp/research-contract.md`에 저장한다:
   ```markdown
   # 리서치 계약: <TOPIC>
   - 핵심 질문: <이 리서치가 답해야 할 단 하나의 질문>
   - 하위 질문: <2~4개>
   - 제외 범위: <조사하지 않을 것>
   - 성공 기준: <최종 보고서가 충족해야 할 조건>
   ```
3. 이 파일의 전체 내용이 `{{CONTRACT}}` 변수로 Step 1~4 프롬프트에 주입된다
   (Step 1은 dispatch-persona.sh가 자동 치환, Step 2~4는 Phase 3에서 오케스트레이터가 치환).

### 0.5-1. LLM 실제 해석 (fallback 포함)

`llm-config.yaml`을 읽고, 5개 페인 각각에 대해 3단계 fallback 체인을 해석하여
실제로 사용될 LLM을 결정한다:

1. **1차**: 페인에 지정된 LLM CLI가 설치되어 있는가? → 있으면 그것을 사용
   단, 해당 LLM이 `non_interactive_unsupported` 목록(예: `codex`)에 있으면
   **설치돼 있어도 미설치로 간주**하고 2차로 넘어간다 — 비대화형(`-p`) 실행이
   불가능해 `stdin is not a terminal` 오류로 실패하기 때문이다.
2. **2차**: 없으면 `pane_fallback[pane]`에 지정된 Claude 티어 CLI가 있는가? → 있으면 그것을 사용
3. **3차**: 없으면 `fallback_llm`(기본값 `claude-sonnet`)을 사용

### 0.5-2. 실행 계획 출력

아래 형식으로 **실제 사용될 LLM**을 사용자에게 보여준다:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STORM 리서치 실행 계획
주제: <TOPIC>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

리서치 계약 (승인 후 불변):
  핵심 질문: <계약의 핵심 질문>
  제외 범위: <계약의 제외 범위>
  성공 기준: <계약의 성공 기준>

페르소나 × LLM 배정:
  Pane 1 | Engineer          | <실제 LLM>  [설정: <원래 지정값>]
  Pane 2 | Economist         | <실제 LLM>  [설정: <원래 지정값>]
  Pane 3 | Regulator         | <실제 LLM>  [설정: <원래 지정값>]
  Pane 4 | Critical Consumer | <실제 LLM>  [설정: <원래 지정값>]
  Pane 5 | Futurist          | <실제 LLM>  [설정: <원래 지정값>]

fallback이 적용된 페인은 ⚠️ 표시.
예) Pane 2 | Economist | claude-sonnet ⚠️  [설정: codex — CLI 없음]

예상 소요 시간: ~10분 (Phase 1 병렬 조사 포함)
출력 위치:
  HTML: dist/<SLUG>/report.html
  Wiki: wiki/AI-Strategy/<SLUG>-storm.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

위 설정으로 리서치를 시작할까요?
승인하면 보고서 완성까지 자동으로 진행됩니다 (추가 확인 없음).

  [y] 승인 — 지금 바로 시작
  [n] 취소 — LLM 설정 변경 후 재실행

> 
```

### 0.5-3. 승인 대기 및 분기

- **사용자가 `y` (또는 `yes`, `진행`, `ok` 등 긍정 응답) 입력** →
  먼저 YOLO 상태 마커 파일을 생성한다 (컨텍스트 압축 후에도 승인 상태 유지용):
  ```bash
  echo "$TOPIC" > "$SKILL_DIR/tmp/.yolo-approved"
  ```
  그 후 아래 메시지를 출력하고 Phase 1로 진행:
  ```
  ✅ 승인됨 — YOLO 모드 시작. 보고서 완성까지 자동 진행합니다.
  ```
  이후 Phase 1~4는 **추가 사용자 확인 없이** 완전 자동으로 실행한다.

- **사용자가 `n` (또는 `no`, `취소`, `cancel`) 입력** →
  아래 메시지를 출력하고 즉시 중단:
  ```
  ❌ 취소됨.
  LLM 설정 변경: E:/My-wiki/project/storm/llm-config.yaml
  변경 후 /storm-research "<TOPIC>" 을 다시 실행하세요.
  ```
  Phase 1로 **진행하지 않는다**.

---

## Phase 1: tmux 페인 초기화 + 페르소나 디스패치

통과 조건: setup-panes.sh + 5개 dispatch-persona.sh 실행 완료 — 출력 수집은 Phase 2에서.

### 1-1. 세션 생성

```bash
bash "$SKILL_DIR/scripts/setup-panes.sh" "$SESSION" "$TOPIC"
```

이 스크립트는 기존 동명 세션을 종료하고 pane 0(오케스트레이터)과 pane 1~5(페르소나)를 생성한다.

### 1-2. 5개 페인에 페르소나 디스패치 (병렬)

아래 5개 명령을 동시에 실행하라 (순차 실행 금지 — 병렬 성능이 핵심이다).

```bash
bash "$SKILL_DIR/scripts/dispatch-persona.sh" "$SESSION" "1" "$TOPIC"
bash "$SKILL_DIR/scripts/dispatch-persona.sh" "$SESSION" "2" "$TOPIC"
bash "$SKILL_DIR/scripts/dispatch-persona.sh" "$SESSION" "3" "$TOPIC"
bash "$SKILL_DIR/scripts/dispatch-persona.sh" "$SESSION" "4" "$TOPIC"
bash "$SKILL_DIR/scripts/dispatch-persona.sh" "$SESSION" "5" "$TOPIC"
```

각 스크립트는 llm-config.yaml을 읽어 해당 페인의 LLM CLI와 페르소나를 결정하고,
`sub-skills/step1-multi-perspective.md` 템플릿의 `{{TOPIC}}`, `{{PERSONA}}`, `{{ASSIGNED_LLM}}`, `{{PANE_ID}}`를 치환하여 tmux 페인에 전송한다.
결과는 `tmp/persona-<N>.md`에 저장된다.

---

## Phase 2: 딥 리서치 수집 대기 (ADR-02)

페르소나 출력이 모두 수집될 때까지 대기한다.

```bash
bash "$SKILL_DIR/scripts/collect-outputs.sh" "$SKILL_DIR" "$SESSION" "$TOPIC" 300
EXIT_CODE=$?
```

통과 조건: EXIT_CODE=0 이고 완료 페인 ≥ 3개. EXIT_CODE=1 이면 STOP — awaiting gate verdict (사용자 개입 필요).

### 실패 처리 (exit 1)

`EXIT_CODE`가 1이면 완료된 페인이 3개 미만이다. 이 경우:

1. 타임아웃된 페인 번호를 확인하여 사용자에게 출력:
   ```
   파이프라인 중단 — 최소 완료 기준(3/5) 미달.
   미완료 페인: <번호 목록>
   tmp/ 파일이 보존되었습니다: $SKILL_DIR/tmp/
   수동으로 페인 결과를 확인하고 /storm-research 를 재실행하거나,
   완료된 파일만으로 계속하려면 Phase 3을 수동으로 실행하세요.
   ```
2. **즉시 중단** — Phase 3으로 진행하지 않는다.

### 성공 처리 (exit 0)

완료 수가 3~5개이면 계속 진행한다.
완료되지 않은 페인이 있을 경우 경고를 출력하고 진행:

```
완료: <N>/5 페인. 미완료 페인은 HTML에 경고 카드로 표시됩니다.
```

완료된 페르소나 출력을 하나로 합쳐 저장:

```bash
cat "$SKILL_DIR/tmp/persona-1.md" \
    "$SKILL_DIR/tmp/persona-2.md" \
    "$SKILL_DIR/tmp/persona-3.md" \
    "$SKILL_DIR/tmp/persona-4.md" \
    "$SKILL_DIR/tmp/persona-5.md" \
    2>/dev/null > "$SKILL_DIR/tmp/step1-all-perspectives.md"
```

(존재하지 않는 파일은 2>/dev/null로 무시한다.)

### 2-2. 관점별 압축본 생성 (토큰 누적 방지 — 필수)

완료된 각 페르소나에 대해 `tmp/persona-<N>.md` 원문을 읽고
압축본 `tmp/persona-<N>-digest.md`를 작성한다. 압축본 구성 (관점당):

- **핵심 주장 3~5개** — 각 1~2문장, 인라인 인용 `[출처명]` 유지
- **Expert Judgment** — 원문 그대로 1줄
- **출처 전량** — 해당 관점이 인용한 출처 목록 전체 (URL 포함, 누락 금지)
- **요약 800자 이내**

작성 후 하나로 합친다:

```bash
cat "$SKILL_DIR/tmp/persona-1-digest.md" \
    "$SKILL_DIR/tmp/persona-2-digest.md" \
    "$SKILL_DIR/tmp/persona-3-digest.md" \
    "$SKILL_DIR/tmp/persona-4-digest.md" \
    "$SKILL_DIR/tmp/persona-5-digest.md" \
    2>/dev/null > "$SKILL_DIR/tmp/step1-digests.md"
```

**Phase 3의 Step 2·3에는 원문(step1-all-perspectives.md)이 아니라 이 압축본만 전달한다.**
원문은 tmp/에 보존되며 HTML 보고서의 관점별 카드(generate-html.py)에 그대로 사용된다.

---

## Phase 3: STORM 파이프라인 Step 2~4 (현재 세션 직접 실행)

메인 Opus가 서브스킬 템플릿을 로드하고 변수를 치환하여 순차 실행한다.
서브에이전트 스폰 금지.

**Step 2 → 3 → 4를 끊김 없이 연속 실행한다 — 사이에서 멈추거나 사용자에게 묻지 않는다**
(YOLO 실행 계약). 각 Step 저장 직후 곧바로 다음 Step을 시작한다.

통과 조건(자가 판정): step2-contradictions.md · step3-synthesis.md · step4-peer-review.md 모두 저장 완료.

### Step 2: 모순 탐색

1. `sub-skills/step2-contradictions.md` 파일 전체를 읽는다.
2. 아래 변수를 치환한다:
   - `{{TOPIC}}` → `<TOPIC>`
   - `{{CONTRACT}}` → `tmp/research-contract.md` 파일의 전체 내용
   - `{{STEP1_OUTPUT}}` → `tmp/step1-digests.md` 파일의 전체 내용 (압축본 — 원문 전달 금지)
3. 치환된 프롬프트 전체를 자신(Main Opus)에게 실행하여 분석 결과를 생성한다.
4. 결과를 `tmp/step2-contradictions.md`에 저장한다.

### Step 3: 종합

1. `sub-skills/step3-synthesis.md` 파일 전체를 읽는다.
2. 아래 변수를 치환한다:
   - `{{TOPIC}}` → `<TOPIC>`
   - `{{CONTRACT}}` → `tmp/research-contract.md` 파일의 전체 내용
   - `{{STEP1_OUTPUT}}` → `tmp/step1-digests.md` 파일의 전체 내용 (압축본 — 원문 전달 금지)
   - `{{STEP2_OUTPUT}}` → `tmp/step2-contradictions.md` 파일의 전체 내용
3. 치환된 프롬프트를 실행하여 통합 보고서를 생성한다 (800~1200 단어).
4. 결과를 `tmp/step3-synthesis.md`에 저장한다.

### Step 4: 동료 심사

1. `sub-skills/step4-peer-review.md` 파일 전체를 읽는다.
2. 아래 변수를 치환한다:
   - `{{TOPIC}}` → `<TOPIC>`
   - `{{CONTRACT}}` → `tmp/research-contract.md` 파일의 전체 내용
   - `{{STEP3_OUTPUT}}` → `tmp/step3-synthesis.md` 파일의 전체 내용
3. 엄격한 동료 심사위원 시각으로 보고서를 검토한다:
   - 출처 신뢰성, 할루시네이션 위험, 논리 일관성, 갭 분석
   - 각 항목에 심각도 **[HIGH/MED/LOW]** + 수정 난이도 **[Easy/Hard]** 태그 부여
4. 결과를 `tmp/step4-peer-review.md`에 저장한다.
5. `tmp/step4-peer-review.md`에서 **Overall Assessment**를 확인하여 분기:
   - `Acceptable` → Phase 3.5로 진행
   - `Needs Revision` → HIGH 항목을 `tmp/step3-synthesis.md`에 즉시 적용 수정 후 Phase 3.5로 진행
     (수정 내용: HIGH 항목만 대상, 새로운 분석 추가 금지 — 기존 오류 교정만)
   - `Major Revision` → 즉시 중단하고 사용자에게 알림:
     ```
     ⚠️  동료 심사 결과: Major Revision 필요
     HIGH 항목 [N]건 발견 — 자동 수정 범위를 초과합니다.
     tmp/step4-peer-review.md를 확인하고 /storm-research 를 재실행하거나
     Step 3을 수동으로 수정한 뒤 Phase 4를 직접 실행하세요.
     ```

---

## Phase 3.5: Export 전 self-check (자가 게이트 — 사용자 확인 아님)

Phase 4로 넘어가기 전에 `tmp/step3-synthesis.md`(Step 4 수정 반영본)를 아래 체크리스트로
검사한다. **하나라도 실패하면 해당 항목을 즉시 보완한 뒤 재검사한다** — 사용자에게 묻지
않는다 (YOLO 계약).

- [ ] 필수 섹션 전부 존재: Executive Summary / Key Findings / Areas of Consensus /
      Unresolved Debates / Synthesis Judgments / Implications / References
- [ ] Executive Summary가 **리서치 계약의 핵심 질문에 직접 답한다**
- [ ] 미인용 결론 0건 — Key Findings·Synthesis Judgments의 모든 주장에 인라인 인용 존재
- [ ] References에 본문 인용 출처가 전량 나열되고, Step 4에서 허구 의심(HIGH)으로 판정된
      출처가 본문·References에 남아 있지 않다

통과 조건(자가 판정): 4개 항목 전부 통과 → 즉시 Phase 4로 진행.

---

## Phase 4: HTML 보고서 + Wiki 노트 생성

generate-html.py 스크립트를 호출한다:

```bash
# python 우선 호출(Windows의 python3는 MS Store 스텁) → 실패 시 python3 폴백(macOS/Linux).
# 명령이 python으로 시작해 권한 allow(Bash(python *)·Bash(python3 *))에 매칭 → 무프롬프트.
python "$SKILL_DIR/scripts/generate-html.py" \
  "$TOPIC" \
  --step2 "$SKILL_DIR/tmp/step2-contradictions.md" \
  --step3 "$SKILL_DIR/tmp/step3-synthesis.md" \
  --step4 "$SKILL_DIR/tmp/step4-peer-review.md" \
  || python3 "$SKILL_DIR/scripts/generate-html.py" \
  "$TOPIC" \
  --step2 "$SKILL_DIR/tmp/step2-contradictions.md" \
  --step3 "$SKILL_DIR/tmp/step3-synthesis.md" \
  --step4 "$SKILL_DIR/tmp/step4-peer-review.md"
```

통과 조건: report.html 과 wiki 노트(.md) 파일 생성 완료 — ✅ 통과 시 완료 보고로 진행.

이 스크립트는:
- `E:/My-wiki/project/storm/dist/<SLUG>/report.html` 생성
- `E:/My-wiki/wiki/AI-Strategy/<SLUG>-storm.md` 생성 (Step 3 내용 ≤500자 압축 + 출처 목록)
- Python 의존성 부재 시 오류 메시지 출력: `pip install pyyaml jinja2 markdown`

Wiki 노트 frontmatter 규격 (스크립트가 자동 생성):

```yaml
---
title: "<TOPIC> STORM 리서치"
type: research
method: STORM
topic: "<TOPIC>"
date: YYYY-MM-DD
llms: [실제 사용된 LLM 목록 — llm-config.yaml에서 읽기]
source: project/storm/dist/<SLUG>/report.html
sources:
  - project/storm/dist/<SLUG>/report.html
---
```

---

## 완료 보고

### 작업 로그 아카이브 (감사 추적 — Phase 0 삭제 전 보존)

모든 Phase가 성공하면 먼저 이번 런의 중간 산출물을 `dist/<SLUG>/logs/`로 복사한다.
다음 런의 Phase 0이 tmp/를 삭제해도 리플레이·감사 추적이 가능하도록 하기 위함이다
(결론에 이의가 제기되면 어느 관점·근거에서 갈라졌는지 이 로그로 추적한다).

```bash
LOG_DIR="$SKILL_DIR/dist/$SLUG/logs"
mkdir -p "$LOG_DIR"
cp -f "$SKILL_DIR"/tmp/research-contract.md \
      "$SKILL_DIR"/tmp/persona-*.md \
      "$SKILL_DIR"/tmp/step*.md \
      "$LOG_DIR/" 2>/dev/null || true
```

### 품질 메트릭 자가 측정

보고서에서 아래 지표를 직접 세어 완료 보고에 포함한다 (자가 보고 — 소프트 지표):

- **출처 수**: step3 References 항목 수
- **미인용 결론**: Key Findings·Synthesis Judgments 중 인라인 인용 없는 항목 수 (Phase 3.5 통과 시 0)
- **주장 등급**: step4 Claim Verification 표의 확정/조건부/미확인 건수
- **압축 보존율**: 압축본(step1-digests.md)에 보존된 출처 수 ÷ 페르소나 원문 출처 수 (목표 ≥0.95)
- **총 글자수(추정)**: step1-digests + step2 + step3 + step4 글자수 합 (목표 ≤90,000)

### 최종 출력

YOLO 마커를 삭제하고 (다음 실행에 잔류 방지) 아래 형식으로 결과를 출력하라:

```bash
rm -f "$SKILL_DIR/tmp/.yolo-approved"
```

```
STORM 리서치 완료: <TOPIC>

HTML 보고서: E:\My-wiki\project\storm\dist\<SLUG>\report.html
Wiki 노트:   E:\My-wiki\wiki\AI-Strategy\<SLUG>-storm.md
작업 로그:   E:\My-wiki\project\storm\dist\<SLUG>\logs\
Session:     <SESSION>

페르소나 완료: <N>/5
  Pane 1: Engineer (claude-sonnet)   - <완료/타임아웃>
  Pane 2: Economist (codex)          - <완료/타임아웃>
  Pane 3: Regulator (kimi)           - <완료/타임아웃>
  Pane 4: Critical Consumer (haiku)  - <완료/타임아웃>
  Pane 5: Futurist (antigravity)     - <완료/타임아웃>

품질 메트릭:
  출처 수:         <N>개
  미인용 결론:     <N>건 (목표 0)
  주장 등급:       확정 <N> / 조건부 <N> / 미확인 <N>
  압축 보존율:     <0.00~1.00> (목표 ≥0.95)
  총 글자수(추정): <N>자 (목표 ≤90,000)
```

---

## 출처 요구사항

모든 페르소나 출력과 종합 보고서에 반드시 포함:
- 논문: `[저자, 연도] 제목, 저널/컨퍼런스`
- 웹: `[사이트명, URL, accessed YYYY-MM-DD]`
- 실제 존재하는 출처만 인용 — 허구 출처 금지 (Step 4에서 검증)

---

## 비목표 (작업 범위 경계)

- 실시간 웹 크롤링 없음 — LLM 내장 지식만 활용
- 페르소나 역할 실행 중 변경 불가 — 실행 전 llm-config.yaml 수정
- 클라우드 전송 없음 — 로컬 전용
