import os

base = r'C:\apex_app\apex_finance\lib'

# Step 1: Create shared_constants.dart with AC class and apiBase
constants_path = os.path.join(base, 'core', 'shared_constants.dart')
constants_content = """import 'package:flutter/material.dart';

const apiBase = 'https://apex-api-ootk.onrender.com';

class AC {
  static const gold = Color(0xFFC9A84C);
  static const navy = Color(0xFF050D1A);
  static const navy2 = Color(0xFF080F1F);
  static const navy3 = Color(0xFF0D1829);
  static const navy4 = Color(0xFF0F2040);
  static const cyan = Color(0xFF00C2E0);
  static const tp = Color(0xFFF0EDE6);
  static const ts = Color(0xFF8A8880);
  static const ok = Color(0xFF2ECC8A);
  static const warn = Color(0xFFF0A500);
  static const err = Color(0xFFE05050);
  static const bdr = Color(0x26C9A84C);
}
"""

with open(constants_path, 'w', encoding='utf-8') as f:
    f.write(constants_content)
print('CREATED core/shared_constants.dart')

# Step 2: Fix each extracted file - replace header imports and add _api alias
extracted_dir = os.path.join(base, 'screens', 'extracted')
files = [
    'subscription_screens.dart',
    'notification_screens_v2.dart',
    'legal_screens_v2.dart',
    'client_screens.dart',
    'coa_screens.dart',
]

new_header = """import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_config.dart';
import '../../core/session.dart';
import '../../core/shared_constants.dart';

const _api = apiBase;

"""

for fname in files:
    fpath = os.path.join(extracted_dir, fname)
    if not os.path.exists(fpath):
        print('SKIP %s (not found)' % fname)
        continue
    
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find where the actual code starts (after the old header imports)
    # Look for first 'class ' or '// ' that isn't an import
    lines = content.split('\n')
    code_start = 0
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith('class ') or (stripped.startswith('//') and i > 3):
            code_start = i
            break
        if stripped and not stripped.startswith('import') and not stripped == '':
            code_start = i
            break
    
    # Rebuild file with new header + original code
    code_lines = lines[code_start:]
    new_content = new_header + '\n'.join(code_lines)
    
    with open(fpath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print('FIXED  %s (added AC + _api imports)' % fname)

# Step 3: Update main.dart to also import shared_constants and keep AC there too
# (AC is used extensively in main.dart itself, so we keep it in both places
#  but main.dart's AC class is the original - shared_constants is for extracted files)

print('')
print('DONE - all extracted files now import AC and _api via shared_constants.dart')
print('Run: flutter analyze 2>&1 | Select-String "error" | Measure-Object')
