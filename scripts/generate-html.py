#!/usr/bin/env python3
"""STORM 리서치 결과를 HTML 보고서와 Wiki 노트로 변환.

LLM 이름과 페르소나 역할은 런타임에 llm-config.yaml에서 읽는다.

의존성: pip install pyyaml jinja2 markdown
"""

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path

try:
    import yaml
    from jinja2 import Environment, FileSystemLoader
    import markdown as md_lib
except ImportError:
    import os
    # #2: 재귀 방지 — 이미 python으로 재시도한 경우 에러 출력 후 종료
    if sys.platform == "win32" and not os.environ.get("_STORM_HTML_RETRY"):
        import subprocess
        env = {**os.environ, "_STORM_HTML_RETRY": "1"}
        sys.exit(subprocess.run(["python", *sys.argv], env=env).returncode)
    print("pip install pyyaml jinja2 markdown 실행 필요", file=sys.stderr)
    sys.exit(1)


# --- 유틸리티 ---

def sanitize_html(html: str) -> str:
    """#3: LLM 출력의 XSS 방어 — <script> 태그·인라인 이벤트 핸들러·javascript: href 제거."""
    html = re.sub(r"<script\b[^>]*>.*?</script>", "", html, flags=re.DOTALL | re.IGNORECASE)
    html = re.sub(r"\s+on\w+\s*=\s*(?:\"[^\"]*\"|'[^']*')", "", html, flags=re.IGNORECASE)
    html = re.sub(r"(href|src)\s*=\s*[\"']javascript:[^\"']*[\"']", r'\1="#"', html, flags=re.IGNORECASE)
    return html


def strip_markdown(text: str) -> str:
    """#9: 마크다운 문법 제거 후 순수 텍스트 반환 — wiki 노트 500자 제한이 가시 문자에 적용되도록."""
    text = re.sub(r"^#{1,6}\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"\*{1,3}([^*\n]+)\*{1,3}", r"\1", text)
    text = re.sub(r"`([^`\n]+)`", r"\1", text)
    text = re.sub(r"^\s*[-*+]\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*\d+\.\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def slugify(topic: str) -> str:
    """주제 문자열을 URL-safe slug로 변환."""
    s = topic.lower()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[\s-]+", "-", s)
    return s.strip("-")


def load_config(skill_dir: Path) -> dict:
    """llm-config.yaml 읽기."""
    config_path = skill_dir / "llm-config.yaml"
    with open(config_path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_persona_outputs(tmp_dir: Path, cfg: dict) -> list:
    """tmp/persona-N.md 읽기. LLM·페르소나 이름은 yaml에서 동적으로 읽음.

    파일이 없거나 비어 있으면 timed_out=True 마킹.
    """
    personas = []
    for i in range(1, 6):
        pane_cfg = cfg["panes"][str(i)]
        f = tmp_dir / f"persona-{i}.md"
        timed_out = not f.exists() or f.stat().st_size == 0
        raw_content = "" if timed_out else f.read_text(encoding="utf-8-sig")
        personas.append({
            "role":      pane_cfg["persona"],
            "llm":       pane_cfg["llm"],
            "content":   sanitize_html(md_lib.markdown(raw_content)),  # #3: XSS 방어
            "timed_out": timed_out,
        })
    return personas


def extract_sources(synthesis_md: str, peer_review_md: str) -> list:
    """출처 목록 추출.

    우선순위:
    1. step3 종합 보고서의 ## References 번호 목록 (주 출처)
    2. step4 peer review의 마크다운 링크 [text](url) (보조)
    """
    seen: set = set()
    sources = []

    # 1. step3 ## References 섹션에서 번호 목록 추출 (영문/한국어 헤더 모두 지원)
    in_refs = False
    for line in synthesis_md.splitlines():
        if re.match(r"^##\s+(References|Sources|출처|참고문헌|참조)", line, re.IGNORECASE):
            in_refs = True
            continue
        if in_refs:
            if line.startswith("##"):  # 다음 섹션 시작 → 종료
                break
            m = re.match(r"^\d+\.\s+(.+)", line)
            if m:
                entry = m.group(1).strip()
                if entry not in seen:
                    seen.add(entry)
                    sources.append(entry)

    # 2. step4 peer review에서 마크다운 링크 추가 (중복 제외)
    links = re.findall(r"\[([^\]]+)\]\((https?://[^\)]+)\)", peer_review_md)
    for text, url in links:
        entry = f"[{text}]({url})"
        if entry not in seen:
            seen.add(entry)
            sources.append(entry)

    return sources


def generate_wiki_note(
    topic: str,
    slug: str,
    cfg: dict,
    synthesis_md: str,
    sources: list,
) -> str:
    """<slug>-storm.md wiki 노트 생성."""
    today = datetime.now().strftime("%Y-%m-%d")
    llm_list = [cfg["panes"][str(i)]["llm"] for i in range(1, 6)]

    # #9: raw 마크다운이 아닌 순수 텍스트 기준 500자 제한 (문법 문자가 예산 잠식 방지)
    body_text = strip_markdown(synthesis_md)
    if len(body_text) > 500:
        body_text = body_text[:497] + "..."

    sources_section = "\n".join(f"- {s}" for s in sources) if sources else "- (없음)"

    frontmatter = (
        "---\n"
        f'title: "{topic} STORM 리서치"\n'
        "type: research\n"
        "method: STORM\n"
        f'topic: "{topic}"\n'
        f"date: {today}\n"
        f"llms: [{', '.join(llm_list)}]\n"
        f"source: project/storm/dist/{slug}/report.html\n"
        f"sources:\n  - project/storm/dist/{slug}/report.html\n"
        "---\n"
    )
    body = f"\n## 종합 요약\n\n{body_text}\n\n## 출처\n\n{sources_section}\n"
    return frontmatter + body


# --- 메인 ---

def main() -> None:
    parser = argparse.ArgumentParser(description="STORM HTML 보고서 및 Wiki 노트 생성")
    parser.add_argument("topic",        help="리서치 주제")
    parser.add_argument("--step2",      required=True, help="Step2 모순 마크다운 경로")
    parser.add_argument("--step3",      required=True, help="Step3 종합 마크다운 경로")
    parser.add_argument("--step4",      required=True, help="Step4 동료심사 마크다운 경로")
    parser.add_argument(
        "--skill-dir",
        default="E:/My-wiki/project/storm",
        help="스킬 루트 디렉터리",
    )
    parser.add_argument(
        "--dist-dir",
        default="E:/My-wiki/project/storm/dist",
        help="HTML 출력 루트 디렉터리",
    )
    parser.add_argument(
        "--wiki-dir",
        default="E:/My-wiki/wiki/AI-Strategy",
        help="Wiki 노트 출력 디렉터리",
    )
    args = parser.parse_args()

    skill_dir = Path(args.skill_dir)
    tmp_dir   = skill_dir / "tmp"

    # 설정 읽기
    cfg      = load_config(skill_dir)
    personas = load_persona_outputs(tmp_dir, cfg)

    slug    = slugify(args.topic)
    out_dir = Path(args.dist_dir) / slug
    out_dir.mkdir(parents=True, exist_ok=True)

    # 마크다운 파일 읽기 및 HTML 변환
    # utf-8-sig: BOM(0xEF BB BF)을 자동으로 제거하여 Windows 환경과 호환
    step2_md = Path(args.step2).read_text(encoding="utf-8-sig")
    step3_md = Path(args.step3).read_text(encoding="utf-8-sig")
    step4_md = Path(args.step4).read_text(encoding="utf-8-sig")

    # Jinja2 HTML 렌더링
    env      = Environment(loader=FileSystemLoader(str(skill_dir / "templates")))
    template = env.get_template("report.html.jinja")

    html = template.render(
        topic          = args.topic,
        generated_at   = datetime.now().strftime("%Y-%m-%d %H:%M"),
        personas       = personas,
        contradictions = sanitize_html(md_lib.markdown(step2_md)),  # #3
        synthesis      = sanitize_html(md_lib.markdown(step3_md)),  # #3
        peer_review    = sanitize_html(md_lib.markdown(step4_md)),  # #3
    )

    out_file = out_dir / "report.html"
    out_file.write_text(html, encoding="utf-8")
    print(f"HTML 보고서 생성: {out_file}")

    # Wiki 노트 생성
    wiki_dir = Path(args.wiki_dir)
    wiki_dir.mkdir(parents=True, exist_ok=True)

    sources    = extract_sources(step3_md, step4_md)
    wiki_note  = generate_wiki_note(args.topic, slug, cfg, step3_md, sources)
    wiki_file  = wiki_dir / f"{slug}-storm.md"
    wiki_file.write_text(wiki_note, encoding="utf-8")
    print(f"Wiki 노트 생성: {wiki_file}")


if __name__ == "__main__":
    main()
