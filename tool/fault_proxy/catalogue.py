"""Print the device checklist from the same metadata the contract tests read."""

import json
from pathlib import Path


def render():
    print("| Scenario | Mode / screen | Failure / copy keys | Required IDs | Expected hits |")
    print("|---|---|---|---|---|")
    for path in sorted((Path(__file__).parent / "scenarios").glob("*.json")):
        item = json.loads(path.read_text())
        expected, device = item["expect"], item["device"]
        copy = " / ".join(str(expected.get(key, "—")) for key in ["kind", "copyTitle", "copyBody"])
        print(f"| {item['scenario']} | {device['mode']} / {device['screen']} | {copy} | {', '.join(device['requiredIds'])} | {device['expectedHits']} |")


if __name__ == "__main__":
    render()
