from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCAN_ROOTS = (
    ROOT / ".github",
    ROOT / "scripts",
    ROOT / "tool",
    ROOT / "docs",
    ROOT / ".claude" / "agent-memory",
)
SUFFIXES = {".md", ".sh", ".yml", ".yaml", ".py", ".js", ".mjs"}
FORBIDDEN_FRAGMENTS = (
    ("docker service ", "roll", "back"),
    ("--update-failure-action ", "roll", "back"),
    ("--", "roll", "back-order"),
    ("shorebird ", "roll", "back"),
    ("## ", "roll", "back"),
    ("roll", "back target"),
    ("roll", "back pointer"),
    ("prove ", "roll", "back"),
)


def sources():
    for source_root in SCAN_ROOTS:
        if not source_root.exists():
            continue
        for path in source_root.rglob("*"):
            if path.is_file() and path.suffix in SUFFIXES:
                yield path, path.read_text(encoding="utf-8").lower()


violations = []
for path, source in sources():
    for fragments in FORBIDDEN_FRAGMENTS:
        forbidden = "".join(fragments)
        if forbidden in source:
            violations.append(f"{path.relative_to(ROOT)}: {forbidden}")

if violations:
    raise SystemExit("Deployment reversion policy violations:\n" + "\n".join(violations))

print("Fail-closed deployment policy verified.")
