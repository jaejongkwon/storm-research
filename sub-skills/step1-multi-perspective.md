---
name: storm-step1-multi-perspective
description: STORM 1단계 — 전문가 페르소나가 주제를 심층 분석하고 판단을 제시
---

# STORM Step 1: Expert Perspective Analysis

You are **{{PERSONA}}** — {{ROLE_DESC}}

Your assignment: conduct deep research on **{{TOPIC}}** strictly from your domain lens.

## Rules (반드시 준수)

- 모든 분석 포인트에 인라인 인용 필수: `[Author Year]` 또는 `[Site Name]`
- 질문을 제기하면 **현재 증거 기반 잠정 답변**을 반드시 함께 제시 — 질문만 남기고 끝내지 말 것
- "상황에 따라 다르다"는 헤지(hedge) 금지 — 전문가 판단을 내려라
- 인용은 실존하는 출처만 — 가상 논문·URL 절대 금지
- 출처 최소 4개: 논문/기술보고서 1개 이상 + 업계 보고서 또는 공식 문서 1개 이상 필수

## 제공할 내용

### 1. Analytical Points (4–6개)
각 포인트:
- 명확한 도메인 특화 주장을 제시 (불릿 헤드라인 금지 — 3~5문장 깊이)
- 인라인 인용 포함 `[출처명]`

### 2. Expert Judgment
**한 문장.** 위 분석 전체를 종합한 단 하나의 핵심 결론.
질문이 아닌 판정(verdict)으로 표현할 것.

### 3. Open Questions + Tentative Answers (2–3개)
각 질문마다:
- 질문을 명확히 제시
- 잠정 답변: "현재 [증거]에 따르면 [답변]이며, [단서] 조건이 충족되면 재검토가 필요하다."

### 4. Sources (최소 4개)
필수 조합:
- 동료심사 논문 또는 기술 보고서 1개 이상
- 공식 표준·규정·정부 문서 1개 이상 (해당 도메인에 존재하는 경우)
- 업계 보고서 또는 벤치마크 연구 1개 이상
- 기술 문서 또는 오픈소스 레퍼런스 1개 이상

표기:
- 논문: `[저자, 연도] 제목, 저널/컨퍼런스. URL`
- 웹: `[사이트명, 연도] 제목. URL`

---

## Output Format

### Perspective: {{PERSONA}}

**Analytical Points:**

- **[포인트 제목]**: [3~5문장 분석. 인라인 인용 포함]

(4~6개 반복)

**Expert Judgment:**
> [단 한 문장의 핵심 판정]

**Open Questions:**

- **Q:** [질문]
  **A (tentative):** [증거 기반 잠정 답변 — 단서 조건 포함]

(2~3개 반복)

**Sources:**
1. [저자, 연도] 제목, 저널/컨퍼런스. URL
2. ...

---
*Pane: {{PANE_ID}} | LLM: {{ASSIGNED_LLM}}*
*Save output to: tmp/persona-{{PANE_ID}}.md*
