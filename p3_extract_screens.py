import os
import sys

m = r'C:\apex_app\apex_finance\lib\main.dart'
with open(m, 'r', encoding='utf-8-sig') as f:
    lines = f.readlines()

total = len(lines)
print('main.dart: %d lines' % total)

header_lines = [
    "import 'package:flutter/material.dart';\n",
    "import 'dart:convert';\n",
    "import 'package:http/http.dart' as http;\n",
    "import '../../core/api_config.dart';\n",
    "import '../../core/session.dart';\n",
    "\n",
]

groups = [
    ('subscription_screens.dart', 2391, 2638, 'SubscriptionScreen + EntitlementGate + PlanComparisonScreen'),
    ('notification_screens_v2.dart', 2637, 2898, 'NotificationCenterScreenV2 + NotificationPrefsScreen'),
    ('legal_screens_v2.dart', 2897, 3030, 'LegalDocumentsScreenV2'),
    ('client_screens.dart', 3362, 3612, 'ClientListScreen + ClientCreateScreen'),
    ('coa_screens.dart', 3611, total, 'CoaUploadScreen + 5 more COA screens'),
]

outdir = r'C:\apex_app\apex_finance\lib\screens\extracted'
os.makedirs(outdir, exist_ok=True)

extracted_ranges = []

for fname, start, end, classes in groups:
    chunk = lines[start-1:end]
    path = os.path.join(outdir, fname)
    with open(path, 'w', encoding='utf-8') as out:
        for hl in header_lines:
            out.write(hl)
        out.writelines(chunk)
    lcount = len(chunk)
    print('  CREATED %s: %d lines (%s)' % (fname, lcount, classes))
    extracted_ranges.append((start-1, end))

new_lines = lines[:]
for start_idx, end_idx in reversed(sorted(extracted_ranges)):
    marker = '// [P3] Extracted to screens/extracted/ - see separate file\n'
    new_lines[start_idx:end_idx] = [marker]

last_import = 0
for i, line in enumerate(new_lines):
    if line.strip().startswith('import '):
        last_import = i

new_imports = [
    "import 'screens/extracted/subscription_screens.dart';\n",
    "import 'screens/extracted/notification_screens_v2.dart';\n",
    "import 'screens/extracted/legal_screens_v2.dart';\n",
    "import 'screens/extracted/client_screens.dart';\n",
    "import 'screens/extracted/coa_screens.dart';\n",
]
for imp in reversed(new_imports):
    new_lines.insert(last_import + 1, imp)

with open(m, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

final_count = len(new_lines)
print('')
print('main.dart: %d -> %d lines' % (total, final_count))
print('DONE')
