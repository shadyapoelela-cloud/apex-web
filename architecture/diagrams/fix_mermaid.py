"""Fix Mermaid syntax: wrap [/path] (rectangle with leading /) with quotes.

Mermaid treats [/X/] as a parallelogram. So [/path] (no trailing /) is invalid syntax.
We convert [/X] -> ["/X"] but preserve [/X/] (true parallelograms).
"""

import re
from pathlib import Path

FILES = [
    '01-current-state.md',
    '02-target-state.md',
    '03-research-findings.md',
    '04-gap-analysis.md',
]

# Pattern: [/X]  where X does NOT end with /  (preserves true parallelograms [/X/])
# Capture: the inside content X
PATTERN = re.compile(r'\[/([^\]\n]*?[^/\n])\]')


def fix(content: str) -> str:
    return PATTERN.sub(lambda m: f'["/{m.group(1)}"]', content)


def main():
    here = Path(__file__).parent
    total_changes = 0
    for name in FILES:
        path = here / name
        original = path.read_text(encoding='utf-8')
        fixed = fix(original)
        if original != fixed:
            # Count changes by counting fixed pattern matches
            changes = len(PATTERN.findall(original))
            path.write_text(fixed, encoding='utf-8')
            print(f"  {name}: fixed {changes} occurrences")
            total_changes += changes
        else:
            print(f"  {name}: no changes")
    print(f"Total: {total_changes} fixes")


if __name__ == '__main__':
    main()
