# storm-research

Stanford STORM 방법론([Shao et al., NAACL 2024](https://arxiv.org/abs/2402.14207)) 기반 딥 리서치 자동화 스킬.

5개 LLM 페르소나가 tmux 멀티 페인에서 병렬 조사 → 4단계 파이프라인 → **HTML 보고서 + Wiki 노트** 이중 출력.

Claude Code 슬래시 커맨드로 실행: `/storm-research "주제"`

---

## 파이프라인

```
/storm-research "ISO 19650 BIM 최신 동향"
        │
        ├─ Phase 0  tmp/ 초기화
        │
        ├─ Phase 1  5개 LLM 페르소나 병렬 디스패치 (tmux)
        │           Engineer · Economist · Regulator · Critical Consumer · Futurist
        │           └→ tmp/persona-1.md ~ persona-5.md
        │
        ├─ Phase 2  출력 수집 대기 (최대 300 s + 재시도 120 s)
        │           완료 ≥ 3개: 경고 후 계속 / < 3개: 파이프라인 중단
        │
        ├─ Phase 3  메인 LLM이 Step 2~4 순차 실행
        │           Step 2: 모순 탐색  → tmp/step2-contradictions.md
        │           Step 3: 종합       → tmp/step3-synthesis.md
        │           Step 4: 동료 심사  → tmp/step4-peer-review.md
        │
        └─ Phase 4  보고서 생성
                    HTML  → dist/<slug>/report.html
                    Wiki  → wiki/AI-Strategy/<slug>-storm.md
```

---

## 사전 요구사항

| 항목 | 최소 버전 | 설치 확인 |
|------|-----------|-----------|
| [Claude Code](https://claude.ai/code) | 최신 | `claude --version` |
| Python 3 | 3.9+ | `python --version` |
| tmux | 3.0+ | `tmux -V` |
| Git | 2.x | `git --version` |

Python 패키지:

```bash
pip install pyyaml jinja2 markdown
```

---

## 설치

### Windows (WSL2)

> Git Bash 또는 PowerShell 5.1 이상 환경을 가정합니다.

**1. WSL2 + tmux 설치**

```powershell
# PowerShell (관리자)
wsl --install
```

WSL2 Ubuntu 터미널을 열고:

```bash
sudo apt update && sudo apt install -y tmux
```

**2. 레포 클론**

```powershell
# PowerShell — 원하는 경로에 클론
git clone https://github.com/jaejongkwon/storm-research "E:\My-wiki\project\storm"
```

**3. Python 패키지 설치**

```powershell
pip install pyyaml jinja2 markdown
```

**4. Windows Junction 생성**

Claude Code가 스킬을 찾을 수 있도록 `~\.claude\skills\` 아래에 Junction을 만듭니다.

```powershell
# PowerShell (관리자 불필요 — 개발자 모드 ON 또는 일반 사용자 Junction)
$target = "E:\My-wiki\project\storm"          # 클론한 경로
$link   = "$env:USERPROFILE\.claude\skills\storm-research"

New-Item -ItemType Junction -Path $link -Target $target
```

확인:

```powershell
(Get-Item $link).Target   # E:\My-wiki\project\storm 출력되면 성공
```

**5. 출력 디렉터리 생성**

`generate-html.py`의 `--dist-dir` · `--wiki-dir` 기본값에 맞춰 생성하거나,
실행 시 `--dist-dir` · `--wiki-dir` 옵션으로 원하는 경로를 지정하세요.

```powershell
mkdir "E:\My-wiki\project\storm\dist"    -Force
mkdir "E:\My-wiki\wiki\AI-Strategy"      -Force
```

---

### macOS

**1. tmux 설치**

```bash
brew install tmux
```

**2. 레포 클론**

```bash
git clone https://github.com/jaejongkwon/storm-research ~/storm-research
```

**3. Python 패키지 설치**

```bash
pip3 install pyyaml jinja2 markdown
```

**4. 심볼릭 링크 생성**

```bash
mkdir -p ~/.claude/skills
ln -s ~/storm-research ~/.claude/skills/storm-research
```

확인:

```bash
readlink ~/.claude/skills/storm-research   # ~/storm-research 출력되면 성공
```

**5. 출력 디렉터리 생성**

기본 경로는 `~/storm-research/dist` 와 `~/wiki/AI-Strategy` 입니다.
경로를 바꾸려면 `llm-config.yaml`이 아닌 `scripts/generate-html.py`의 `--dist-dir` · `--wiki-dir` 옵션을 사용하세요.

```bash
mkdir -p ~/storm-research/dist
mkdir -p ~/wiki/AI-Strategy
```

---

## 설치 확인 (스모크 테스트)

라이브 LLM 호출 없이 파이프라인 전체를 검증합니다.

```bash
# Windows (Git Bash / WSL)
bash scripts/smoke-test.sh

# macOS
bash scripts/smoke-test.sh
```

```
========================================================
 STORM smoke test
========================================================
[1] ADR-01: pane 3 persona assertion
  PASS: pane 3 persona is 'Regulator'
[2] slugify function
  PASS: slugify('BIM 자동화 테스트') = 'bim-자동화-테스트'
[3] HTML file content checks
  PASS: report.html exists
  ...
========================================================
 Results: 12 passed, 0 failed
 STORM smoke test: ALL CHECKS PASSED
========================================================
```

---

## LLM 설정

`llm-config.yaml` 하나만 편집하면 됩니다 — 코드 수정 불필요.

```yaml
panes:
  "1":
    persona: Engineer
    llm: claude-sonnet      # ← 이 줄만 바꾸면 됨
  "2":
    persona: Economist
    llm: codex
  "3":
    persona: Regulator
    llm: kimi
  "4":
    persona: Critical Consumer
    llm: claude-haiku
  "5":
    persona: Futurist
    llm: antigravity

llm_commands:
  claude-opus:    "claude --model claude-opus-4-8 -p"
  claude-sonnet:  "claude --model claude-sonnet-4-6 -p"
  claude-haiku:   "claude --model claude-haiku-4-5 -p"
  codex:          "codex"
  antigravity:    "antigravity run"
  kimi:           "kimi chat"
  # 새 LLM: 이 섹션에 한 줄 추가

fallback_llm: claude-sonnet   # 지정 CLI 미설치 시 자동 대체
```

지정한 LLM CLI가 없으면 `claude-sonnet`으로 자동 fallback하고 경고를 출력한 뒤 계속 진행합니다.

---

## 사용법

Claude Code에서:

```
/storm-research "ISO 19650 BIM 최신 동향"
/storm-research "생성형 AI 거버넌스 규제 동향"
/storm-research "RAG 파이프라인 설계 원칙"
```

**출력 결과:**

| 파일 | 경로 |
|------|------|
| HTML 보고서 | `dist/<slug>/report.html` |
| Wiki 노트 | `wiki/AI-Strategy/<slug>-storm.md` (기본값 기준) |

---

## 페르소나 역할

| Pane | 역할 | 관점 |
|------|------|------|
| 1 | **Engineer** | 기술 구현 가능성, 시스템 아키텍처 |
| 2 | **Economist** | 비용·효율·시장 영향 |
| 3 | **Regulator** | ISO 표준·법규·AI 거버넌스 |
| 4 | **Critical Consumer** | 실사용자 관점·리스크·한계 |
| 5 | **Futurist** | 장기 트렌드·파괴적 시나리오 |

`llm-config.yaml`의 `persona` 필드를 바꾸면 역할을 자유롭게 교체할 수 있습니다.

---

## 비목표

- 실시간 웹 크롤링 없음 — LLM 내장 지식만 활용
- 클라우드 전송 없음 — 로컬 전용
- 다수 사용자 동시 실행 미지원 (단일 운영자 전제)

---

## 참고

- Stanford STORM 논문: [Shao et al., NAACL 2024](https://arxiv.org/abs/2402.14207)
- PRD: [`PRD.md`](PRD.md)
- 스킬 오케스트레이터: [`SKILL.md`](SKILL.md)
