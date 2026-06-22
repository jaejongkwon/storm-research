# PRD — STORM Research Skill

> Stanford STORM 방법론(Shao et al., NAACL 2024) 기반 딥 리서치 자동화 스킬
> 작성일: 2026-06-22 | 상태: 검토 중

---

## 1. 문제 (Problem)

KECC 기술연구소에서 특정 주제를 깊이 조사하려면 수시간의 수동 검색·정리가 필요하다.
단일 관점으로 조사하면 사각지대가 생기고, 출처 없는 요약은 신뢰하기 어렵다.
대화는 증발하고, 리서치 결과물이 재사용 가능한 형태로 보관되지 않는다.

**핵심 명제:**
"주제를 던지면, 5명의 전문가가 각자의 LLM으로 병렬 조사하고, 4단계를 거쳐 인용 가능한 보고서를 자동 생성한다."

---

## 2. 목표 / 비목표

### 목표 (Goals)

| ID | 목표 |
|----|------|
| G1 | `/storm-research [주제]` 한 명령으로 전체 파이프라인 실행 |
| G2 | 5개 LLM 페르소나가 CMUX 멀티 페인에서 병렬 딥 리서치 수행 |
| G3 | 모든 출력에 검증 가능한 출처(URL + 날짜 또는 논문 인용) 포함 |
| G4 | 4단계 STORM 파이프라인(다관점→모순→종합→동료심사) 자동 실행 |
| G5 | 결과물을 HTML 보고서 + wiki 노트 양쪽으로 저장 |
| G6 | LLM 배분을 `llm-config.yaml` 한 파일로 언제든지 변경 가능 |
| G7 | 특정 LLM이 없을 경우 자동 fallback(기본: claude-sonnet) 후 계속 진행 |

### 비목표 (Non-goals)

| ID | 비목표 |
|----|--------|
| N1 | 실시간 웹 크롤링 / 브라우저 자동화 (현재 LLM 내장 지식 활용) |
| N2 | 클라우드 업로드 / 외부 전송 (로컬 전용) |
| N3 | 다수 사용자 동시 실행 (단일 운영자 전제) |
| N4 | 페르소나 역할 실시간 변경 (실행 전 config로 설정, 실행 중 변경 불가) |
| N5 | LLM 응답 실시간 스트리밍 UI |

---

## 3. 사용자

| 페르소나 | 니즈 |
|----------|------|
| 기술연구소장(주 운영자) | 주제만 던지면 인용 가능한 보고서가 자동 생성 |
| Claude Code 에이전트(메인 Opus) | 5개 페인 오케스트레이션, 파이프라인 조율 |
| LLM 페르소나 에이전트 (×5) | 각자 독립적으로 딥 리서치 후 출처 포함 결과 기록 |

---

## 4. 제품 원칙

- **단일 커맨드 진입**: `/storm-research [주제]`만 입력하면 모든 것이 자동 실행
- **출처 필수**: 출처 없는 결과물은 실패로 취급 — Step 4 동료심사가 검증
- **LLM 교체 가능성**: 코드 수정 없이 yaml 파일 편집만으로 LLM 변경
- **결과물 이중 보존**: HTML(`dist/`) + 마크다운(`wiki/`) 양쪽 저장
- **Graceful Degradation**: LLM CLI가 없으면 경고 후 fallback, 중단하지 않음

---

## 5. 기능 요구사항

### 5-1. LLM 설정 (`llm-config.yaml`)

- 5개 페인 각각에 LLM 타입 + 페르소나 역할 지정
- 지원 LLM: `claude-opus`, `claude-sonnet`, `claude-haiku`, `codex`, `antigravity`, `kimi`
- 새 LLM 추가: yaml의 `llm_commands` 섹션에 CLI 명령만 추가
- Fallback: 지정 LLM CLI 미발견 시 → `claude-sonnet`으로 자동 대체 + 경고 출력

### 5-2. CMUX 멀티 페인 오케스트레이션

- 메인 Opus가 CMUX 세션에 5개 페인 자동 생성
- 각 페인에 페르소나 역할 + STORM Step 1 프롬프트 전송 (`cmux send` 또는 `tmux send-keys`)
- 페인 간 직접 통신 없음 — 모든 결과는 `tmp/persona-N.md` 파일 경유
- 완료 대기: 파일 크기 > 0 확인 방식, 타임아웃 300초

### 5-3. STORM 4단계 파이프라인

| 단계 | 실행 주체 | 입력 | 출력 |
|------|-----------|------|------|
| Step 1: 다관점 분석 | 5개 LLM 페인 (병렬) | 주제 | `tmp/persona-N.md` × 5 |
| Step 2: 모순 탐색 | 메인 Opus | Step 1 통합 | `tmp/step2-contradictions.md` |
| Step 3: 종합 | 메인 Opus | Step 1+2 | `tmp/step3-synthesis.md` |
| Step 4: 동료심사 | 메인 Opus | Step 3 | `tmp/step4-peer-review.md` |

### 5-4. 출력 결과물

**HTML 보고서** (`project/storm/dist/<topic-slug>/report.html`)
- 5개 페르소나 카드 + LLM 배지
- 모순·종합·동료심사 섹션
- 인라인 출처 링크

**Wiki 노트** (`wiki/AI-Strategy/<topic-slug>-storm.md`)
- Frontmatter: `type: research`, `method: STORM`, `topic`, `date`, `llms`
- Step 3 종합 내용 압축 (≤500자)
- 출처 목록

### 5-5. 페르소나 역할 (기본값)

| Pane | 역할 | 변경 방법 |
|------|------|-----------|
| 1 | Engineer (기술 엔지니어) | `llm-config.yaml` 수정 |
| 2 | Economist (경제학자) | `llm-config.yaml` 수정 |
| 3 | **Regulator** (규제·표준·법규 전문가) | `llm-config.yaml` 수정 |
| 4 | Critical Consumer (비판적 소비자) | `llm-config.yaml` 수정 |
| 5 | Futurist (미래학자) | `llm-config.yaml` 수정 |

---

## 6. 성공 기준

| 기준 | 측정 방법 |
|------|-----------|
| 파이프라인 완주 | 3개 이상 페인 완료 + `tmp/persona-N.md` 생성 (최소 완료 기준) |
| 출처 포함 | Step 4 동료심사가 "출처 편향 없음" 판정 |
| HTML 생성 | `dist/<slug>/report.html` 파일 존재 + 브라우저 렌더링 정상 |
| Wiki 저장 | `wiki/AI-Strategy/<slug>-storm.md` 생성 + lint 통과 |
| LLM 교체 | yaml 수정 후 재실행 시 변경된 LLM 반영 확인 |

---

## 7. 기술 제약

- **환경**: Windows 11 Pro + WSL/Git Bash 혼용
- **터미널**: CMUX (tmux-compatible, `tmux send-keys` 호환)
- **런타임**: Python 3 (yaml, jinja2, markdown 패키지)
- **로컬 경로**: 스킬 → `E:\My-wiki\.claude\skills\storm-research\`
- **전역 접근**: `C:\Users\KECC\.claude\skills\storm-research` (Windows Junction)
- **출력 경로**: `E:\My-wiki\project\storm\dist\<slug>\`
- **Wiki 경로**: `E:\My-wiki\wiki\AI-Strategy\<slug>-storm.md`

---

## 8. 열린 질문 (검토 후 결정)

| # | 질문 | 현재 결정 |
|---|------|----------|
| Q1 | 페르소나 역할을 주제별로 동적 변경? | **No** — config로 사전 설정, 실행 중 고정 |
| Q2 | LLM CLI 미설치 시 동작? | **Fallback** — claude-sonnet으로 대체 + 경고 |
| Q3 | 단계별 중간 확인 필요? | **No** — 완전 자동, 완료 후 결과만 보고 |
| Q4 | HTML + wiki 노트 동시 생성? | **Yes** — 양쪽 모두 생성 |
| Q5 | 페인 타임아웃 초과 시? | **1회 재시도(+120초) → 3개 이상 완료 시 경고 후 계속 / 2개 이하 시 파이프라인 중단** |

---

## 9. 설계 결정 기록 (ADR)

### ADR-01: Pane 3 역할 — Historian → Regulator

**변경 전:** Historian (역사학자)
**변경 후:** Regulator (규제·표준·법규 전문가)

**이유:**
STORM의 핵심은 사각지대 없는 다관점 분석이다. KECC 도메인(토목·BIM·AI 전략)에서 역사적 관점은 대부분의 주제에서 억지스럽게 적용된다. BIM 자동화나 RAG 파이프라인에 역사학자 관점은 분석의 깊이를 더하지 못한다.

반면 Regulator 관점은 KECC 업무의 핵심 맥락과 직결된다:
- ISO 19650, IFC, OWL 등 국제 표준 준수 여부
- AI 거버넌스·데이터 보호 규제 동향
- 건설 관련 법규 및 발주처 요구사항

**시사점:**
- `llm-config.yaml`의 `persona` 필드만 변경하면 되므로 코드 영향 없음
- Step 1 프롬프트(`step1-multi-perspective.md`)의 페르소나 예시 설명도 Regulator로 갱신 필요
- 향후 주제별로 Regulator 대신 Ethicist(AI 윤리), Practitioner(현장 시공) 등으로 교체 가능 — 같은 방식으로

---

### ADR-02: 타임아웃 처리 — 단순 계속 → 재시도 + 최소 완료 기준

**변경 전:** 타임아웃 시 완료된 페인 결과만으로 계속 진행
**변경 후:** 1회 재시도(+120초) → 완료 3개 이상이면 경고 후 계속 / 2개 이하면 파이프라인 중단

**이유:**
STORM의 가치는 **다관점 교차 분석**에서 나온다. 단순히 "완료된 것만 쓰면 된다"는 접근은 두 가지 문제를 만든다.

1. **분석 편향**: 페르소나가 누락되면 Step 2(모순 탐색)에서 교차점이 줄어들고, Step 4(동료심사)가 "관점 누락"을 결함으로 플래그한다. 보고서가 생성되었어도 STORM의 효과를 절반만 얻는다.
2. **일시적 실패 무방비**: LLM CLI 콜드 스타트, 네트워크 지연 등 일시적 원인으로 타임아웃이 발생할 수 있다. 재시도 없이 결과를 포기하는 것은 과도한 손실이다.

**최소 완료 기준 3개의 근거:**
Step 2 모순 탐색은 관점 간 대조가 핵심이다. 2개 이하면 "다관점"이 아닌 "양자 대립"이 되어 STORM의 설계 의도와 어긋난다. 3개 이상이면 Engineer·Regulator·Futurist처럼 기술·제도·미래 축의 삼각 구도가 성립한다.

**시사점:**
- `collect-outputs.sh`에 재시도 로직 추가 필요 (타임아웃된 pane-id만 선별 재디스패치)
- HTML 보고서에 타임아웃된 페르소나를 "⚠️ 응답 없음" 카드로 명시 — 누락 사실을 숨기지 않음
- 중단 시 `tmp/` 파일은 보존 → 사용자가 개별 페인 결과 확인 후 수동 재실행 가능
- 플랜의 Task 3(collect-outputs.sh)과 Task 6(통합 테스트)에 이 로직 반영 필요

---

## 10. 파일 구조 (요약)

```
E:\My-wiki\
├── project\storm\
│   ├── PRD.md                    ← 이 파일
│   ├── dist\<slug>\report.html   ← HTML 보고서 출력
│   └── raw\                      ← 원천 자료 보관
├── wiki\AI-Strategy\
│   └── <slug>-storm.md           ← wiki 노트 출력
└── .claude\skills\storm-research\
    ├── SKILL.md                  ← 메인 오케스트레이터
    ├── llm-config.yaml           ← LLM 배분 설정
    ├── sub-skills\               ← 4단계 프롬프트
    ├── scripts\                  ← 자동화 스크립트
    ├── templates\                ← HTML 템플릿
    └── tmp\                      ← 실행 중 임시 파일
```

---

## 11. 관련 문서

- 원문 스펙: `raw/스탠퍼드 STOM 기반 클로드 리서티 스킬 제작.md`
- 구현 플랜: `docs/superpowers/plans/2026-06-22-storm-research-skill.md`
- Vault PRD: `PRD.md`
- Stanford STORM 논문: Shao et al., NAACL 2024 (https://arxiv.org/abs/2402.14207)
