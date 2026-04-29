#!/usr/bin/env bash
# STRICT orphan detection: counts INSTANTIATION patterns (`ClsName(`)
# anywhere in lib/. A class with 0 instantiations is a true orphan,
# even if its name appears elsewhere (e.g. in `State<ClsName>` or imports).
#
# A canonical screen is instantiated 1+ times (in a GoRoute or another widget).
# An orphan is defined but never invoked.
#
# Usage (from repo root):
#   bash architecture/migration/find_orphans_strict.sh > /tmp/orphan_strict.tsv

set -uo pipefail

LIB="apex_finance/lib"
[ -d "$LIB" ] || { echo "Run from repo root" >&2; exit 1; }

mapfile -t DEFS < <(
  grep -rEn '^\s*class [A-Z][A-Za-z0-9_]*(Screen|Page|Hub)\b' "$LIB" \
    --include='*.dart' \
    | sed -E 's|^([^:]+):[0-9]+:[[:space:]]*class[[:space:]]+([A-Za-z0-9_]+).*$|\1\t\2|' \
    | sort -u
)

echo "Found ${#DEFS[@]} screen-like classes" >&2

for line in "${DEFS[@]}"; do
  file="${line%%$'\t'*}"
  cls="${line##*$'\t'}"
  # Count instantiation patterns: ClsName(  in files OTHER than the def file.
  # If a class is only used inside its def file (e.g., a private helper screen
  # in main.dart that someone forgot to remove), we still flag it as orphan
  # because it's never instantiated by the router or another widget.
  # However, internal use within main.dart is legitimate for stateful screens
  # (State<X>), so this script flags candidates — manual review needed.
  external_inst=$(
    {
      grep -rl --include='*.dart' "${cls}(" "$LIB" 2>/dev/null || true
    } | grep -vFx "$file" 2>/dev/null | wc -l
  )
  printf '%s\t%s\t%s\n' "$external_inst" "$file" "$cls"
done | sort -n
