import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_FRAGMENTS = (
    ("docker service ", "roll", "back"),
    ("--update-failure-action ", "roll", "back"),
    ("--", "roll", "back-order"),
    ("shorebird ", "roll", "back"),
    ("## ", "roll", "back"),
    ("roll", "back target"),
    ("roll", "back pointer"),
    ("prove ", "roll", "back"),
    ("docker service ", "rm"),
    ("git ", "re", "vert"),
    ("alembic ", "down", "grade"),
    ("mix ecto.", "roll", "back"),
    ("goose ", "down"),
    ("restore ", "previous image"),
    ("restore ", "prior image"),
)


def sources():
    tracked = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=ROOT
    ).decode("utf-8")
    for relative_path in tracked.split("\0"):
        if not relative_path:
            continue
        path = ROOT / relative_path
        if path.name.endswith(".lock"):
            continue
        try:
            source = path.read_text(encoding="utf-8").lower()
        except (UnicodeDecodeError, OSError):
            continue
        yield path, source


violations = []
for path, source in sources():
    for fragments in FORBIDDEN_FRAGMENTS:
        forbidden = "".join(fragments)
        if forbidden in source:
            violations.append(f"{path.relative_to(ROOT)}: {forbidden}")

if violations:
    raise SystemExit("Deployment reversion policy violations:\n" + "\n".join(violations))

print("Fail-closed deployment policy verified.")
