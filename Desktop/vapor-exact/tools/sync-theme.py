"""Translate Vapor's shared design tokens into Exact's theme and constants."""
import json
import sys
from pathlib import Path

app = Path(__file__).resolve().parents[1]
tokens = json.loads((app.parents[1] / "tokens.json").read_text())
theme = ["tamber vapor", "", "theme"]
for group in tokens["colors"].values():
    theme.extend(f"  vapor.{name} = {value.lower()}  scheme=fixed" for name, value in group.items())
constants = []
for group in ("spacing", "radii"):
    for name, value in tokens[group].items():
        constants.append(f'fn {group}{name.capitalize()}(): number = {value}')
for name, value in tokens["motion"]["durations"].items():
    constants.append(f'fn duration{name.capitalize()}(): number = {value}')
for name, value in tokens["motion"]["curves"].items():
    constants.append(f'fn curve{name.capitalize()}(): string = {json.dumps(value)}')

for name, lines in (("app.tamber", theme), ("tokens.contract", constants)):
    path = app / name
    content = "\n".join(lines) + "\n"
    if "--check" in sys.argv:
        if path.read_text() != content:
            raise SystemExit(f"{path.name} is stale. Run tools/sync-theme.py.")
    else:
        path.write_text(content)
