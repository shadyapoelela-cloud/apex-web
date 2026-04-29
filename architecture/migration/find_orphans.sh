#!/usr/bin/env bash
# Orphan Screen Detection for APEX Flutter app.
#
# For every `class FooScreen|FooPage|FooHub extends ...` defined under
# apex_finance/lib/, count cross-file references in apex_finance/lib/.
# Orphans = classes with 0 references outside their own definition file.
#
# Usage (from repo root):
#   bash architecture/migration/find_orphans.sh > /tmp/orphan_raw.tsv
#
# Output columns (TAB-separated):
#   <ref_count>\t<defining_file>\t<class_name>
#
# Lower ref_count = more orphan-like.
set -euo pipefail

LIB="apex_finance/lib"
[ -d "$LIB" ] || { echo "Run from repo root (cwd missing $LIB)" >&2; exit 1; }

# 1) Find all "class XScreen|XPage|XHub" definitions in lib/.
#    Only widget-like classes (Screen / Page / Hub suffix).
#    Output: file<TAB>class
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
  # Count ALL references to the class name (word boundary) anywhere in lib/,
  # MINUS the single definition line ("class Cls ..."). 0 = truly orphan.
  # The class definition itself contributes 1 hit; subtract it.
  total=$(grep -rn --include='*.dart' -w "$cls" "$LIB" 2>/dev/null | wc -l || echo 0)
  uses=$(( total - 1 ))
  [ "$uses" -lt 0 ] && uses=0
  printf '%s\t%s\t%s\n' "$uses" "$file" "$cls"
done | sort -n
