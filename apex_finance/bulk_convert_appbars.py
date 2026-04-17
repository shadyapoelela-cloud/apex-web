"""One-off script to swap plain Material `appBar: AppBar(...)` patterns
for `appBar: ApexAppBar(...)` across all Flutter screens.

Not part of the running app. Kept in-tree for reproducibility.
"""
from __future__ import annotations

import glob
import os
import re


def main() -> None:
    files = glob.glob("lib/screens/**/*.dart", recursive=True)
    converted = []
    skipped = []
    for p in files:
        with open(p, "r", encoding="utf-8") as f:
            s = f.read()
        if "ApexAppBar" in s:
            continue
        if "appBar: AppBar" not in s:
            continue
        if re.search(r"appBar: AppBar\([^)]*bottom:\s*TabBar", s, flags=re.DOTALL):
            skipped.append(f"{p} (TabBar.bottom)")
            continue
        if re.search(r"appBar: AppBar\([^)]*PopupMenuButton", s, flags=re.DOTALL):
            skipped.append(f"{p} (PopupMenu)")
            continue

        original = s

        rel = p.replace(os.sep, "/")
        parts = rel.split("/")
        up = len(parts) - 2  # drop 'lib' + file
        core_path = "../" * up + "core"

        if f"import '{core_path}/apex_app_bar.dart';" not in s:
            theme_stmt = f"import '{core_path}/theme.dart';"
            new_imports = (
                f"import '{core_path}/apex_app_bar.dart';\n"
                f"import '{core_path}/apex_sticky_toolbar.dart';\n"
            )
            if theme_stmt in s:
                s = s.replace(theme_stmt, new_imports + theme_stmt, 1)
            else:
                s = s.replace(
                    "import 'package:flutter/material.dart';",
                    "import 'package:flutter/material.dart';\n" + new_imports.rstrip(),
                    1,
                )

        # Pattern A — no actions, multi-line.
        s2 = re.sub(
            r"appBar: AppBar\(\s*title:\s*Text\('([^']*)',\s*style:\s*TextStyle\(color:\s*AC\.gold\)\),\s*backgroundColor:\s*AC\.navy2,?\s*\),",
            r"appBar: ApexAppBar(title: '\1'),",
            s,
            flags=re.DOTALL,
        )
        # Pattern B — no actions, single-line.
        s2 = re.sub(
            r"appBar: AppBar\(title: Text\('([^']*)', style: TextStyle\(color: AC\.gold\)\),\s*backgroundColor: AC\.navy2\),",
            r"appBar: ApexAppBar(title: '\1'),",
            s2,
        )

        def _with_refresh(m: re.Match) -> str:
            title = m.group(1)
            handler = m.group(2).strip()
            return (
                f"appBar: ApexAppBar(title: '{title}', actions: ["
                f"ApexToolbarAction(label: 'تحديث', icon: Icons.refresh, "
                f"onPressed: {handler})]),"
            )

        # Pattern C — single refresh IconButton action.
        s2 = re.sub(
            r"appBar: AppBar\(\s*title:\s*Text\('([^']*)',\s*style:\s*TextStyle\(color:\s*AC\.gold\)\),\s*backgroundColor:\s*AC\.navy2,\s*actions:\s*\[\s*IconButton\(\s*icon:\s*Icon\(Icons\.refresh,\s*color:\s*AC\.gold\),\s*(?:tooltip:\s*'[^']*',\s*)?onPressed:\s*([^,)]+),?\s*\),?\s*\],?\s*\),",
            _with_refresh,
            s2,
            flags=re.DOTALL,
        )

        if s2 == original:
            skipped.append(f"{p} (no pattern)")
            continue

        if "ApexToolbarAction" not in s2:
            s2 = s2.replace(f"import '{core_path}/apex_sticky_toolbar.dart';\n", "")

        with open(p, "w", encoding="utf-8") as f:
            f.write(s2)
        converted.append(p)

    print(f"Converted: {len(converted)}")
    for n in converted:
        print(f"  + {n}")
    print(f"Skipped: {len(skipped)}")
    for n in skipped:
        print(f"  - {n}")


if __name__ == "__main__":
    main()
