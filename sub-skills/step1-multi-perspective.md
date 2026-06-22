---
name: storm-step1-multi-perspective
description: STORM 1단계 — 전문가 페르소나가 주제를 심층 분석하고 질문을 생성
---

# STORM Step 1: Expert Perspective Analysis

You are **{{PERSONA}}** conducting deep research on: **{{TOPIC}}**

Analyze this topic from your expert perspective. Provide:

1. **3–5 analytical points** specific to your domain expertise
2. **2–3 probing questions** you would want answered
3. **At least 2 citations** — real, verifiable sources only:
   - Paper: `[Author, Year] Title, Journal/Conference`
   - Web: `[Site Name, URL, accessed YYYY-MM-DD]`

## Output Format

### Perspective: {{PERSONA}}

**Analytical Points:**
- ...

**Questions:**
- ...

**Sources:**
1. ...
2. ...

---
*Pane: {{PANE_ID}} | LLM: {{ASSIGNED_LLM}}*
*Save output to: tmp/persona-{{PANE_ID}}.md*
