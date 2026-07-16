---
name: storm-step4-peer-review
description: STORM 4단계 — 보고서를 동료 심사위원 시각으로 검증
---

# STORM Step 4: Self Peer Review

## Research Contract (불변 — 판정 기준)
{{CONTRACT}}

## Report Under Review
{{STEP3_OUTPUT}}

## Task
엄격한 동료 심사위원으로서 다음을 검토하라:

### 1. Source Reliability
- 인용된 출처가 실제로 존재하고 검증 가능한가?
- 단일 유형 출처에 과도하게 의존하는가?
- 반대 관점이 동등한 품질의 출처로 뒷받침되는가?

### 2. Hallucination Check
- 불확실해 보이는 통계·날짜·인용 명시
- 인용 없는 주장 목록화
- 검증이 필요한 인물명·논문·사건 목록화

### 3. Logical Coherence
- 5개 관점이 공정하게 대표되는가?
- 모순이 회피되지 않고 다루어졌는가?
- Executive Summary와 본문이 일관성 있는가?

### 4. Gap Analysis
- 미해결 핵심 질문은 무엇인가?
- 누락된 관점은 무엇인가?
- 권장 후속 리서치는 무엇인가?
- 결론이 리서치 계약의 핵심 질문에 답하는가? 제외 범위 침범은 없는가?

### 5. Claim Verification (주장 등급 판정)
보고서의 핵심 주장 **최대 8개**를 추출하고, 인용된 출처의 성격에 따라 등급을 부여하라
(웹 접근 없음 — 원문 대조 불가 시 정직하게 미확인으로 격하):
- **확정** — 1차 출처 인용 (표준·정부 고시/지침·공식 기관 문서·동료심사 논문)
- **조건부** — 2차 출처만 인용 (업계 보고서·벤더 자료·기술 블로그·언론)
- **미확인** — 인용 없음, 출처 간 충돌, 또는 출처 실존 여부 검증 불가

## Output Format

### Peer Review: {{TOPIC}}

**Overall Assessment:** [Acceptable / Needs Revision / Major Revision]

**수정 필요 항목 요약:** HIGH N건 | MED N건 | LOW N건

**Source Reliability Issues:**
- **[HIGH/MED/LOW | Easy/Hard]** 항목 설명...

(각 항목에 심각도[HIGH/MED/LOW]와 수정 난이도[Easy/Hard] 태그 필수)

**Potential Hallucinations to Verify:**
- **[HIGH/MED/LOW | Easy/Hard]** 항목 설명...

**Logical Issues:**
- **[HIGH/MED/LOW | Easy/Hard]** 항목 설명...

**Recommended Additions:**
- **[HIGH/MED/LOW | Easy/Hard]** 항목 설명...

**Claim Verification:**

| # | 핵심 주장 (1문장) | 등급 | 근거 출처 |
|---|------------------|------|-----------|
| 1 | ... | 확정/조건부/미확인 | [출처명] 또는 (없음) |

(최대 8행. **미확인** 등급 주장이 Executive Summary에 확정 어조로 포함되어 있으면
Logical Issues에 **[HIGH]**로 추가할 것.)

**Final Verdict:**
[1–2문장: 보고서 발행 적합성 및 필수 수정 사항. HIGH 항목이 1건 이상이면 "Needs Revision" 이상으로 판정.]
