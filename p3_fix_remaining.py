import os

base = r'C:\apex_app\apex_finance\lib'

# Fix 1: Remove apiBase from shared_constants.dart (keep only AC)
sc = os.path.join(base, 'core', 'shared_constants.dart')
with open(sc, 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace("const apiBase = 'https://apex-api-ootk.onrender.com';\n\n", '')
with open(sc, 'w', encoding='utf-8') as f:
    f.write(content)
print('FIX 1: Removed apiBase from shared_constants.dart')

# Fix 2: In all extracted files, change "const _api = apiBase;" to "final _api = apiBase;"
# and remove import of shared_constants if api_config already provides apiBase
extracted_dir = os.path.join(base, 'screens', 'extracted')
files = [
    'subscription_screens.dart',
    'notification_screens_v2.dart',
    'legal_screens_v2.dart',
    'client_screens.dart',
    'coa_screens.dart',
]

for fname in files:
    fpath = os.path.join(extracted_dir, fname)
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix const -> final for _api
    content = content.replace('const _api = apiBase;', 'final _api = apiBase;')
    
    with open(fpath, 'w', encoding='utf-8') as f:
        f.write(content)
    print('FIX 2: %s - const _api -> final _api' % fname)

# Fix 3: coa_screens.dart needs "import 'dart:html' as html;"
coa = os.path.join(extracted_dir, 'coa_screens.dart')
with open(coa, 'r', encoding='utf-8') as f:
    content = f.read()
if "dart:html" not in content:
    content = content.replace(
        "import 'dart:convert';",
        "import 'dart:convert';\nimport 'dart:html' as html;",
        1
    )
    with open(coa, 'w', encoding='utf-8') as f:
        f.write(content)
    print('FIX 3: coa_screens.dart - added dart:html import')

# Fix 4: client_screens.dart needs CoaUploadScreen import (from coa_screens.dart)
# and ClientCreateScreen2 reference - let me check what it actually references
cl = os.path.join(extracted_dir, 'client_screens.dart')
with open(cl, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import for coa_screens (CoaUploadScreen is used in client_screens)
if 'coa_screens.dart' not in content:
    content = content.replace(
        "import '../../core/shared_constants.dart';",
        "import '../../core/shared_constants.dart';\nimport 'coa_screens.dart';",
        1
    )

# Check if ClientCreateScreen2 exists or if it should be ClientCreateScreen
# Based on the class map, there's ClientCreateScreen at L3448
# If the code references ClientCreateScreen2, it might be from client_create.dart
if 'ClientCreateScreen2' in content:
    # Add import for the external client_create.dart
    if "client_create.dart" not in content:
        content = content.replace(
            "import '../../core/shared_constants.dart';",
            "import '../../core/shared_constants.dart';\nimport '../../client_create.dart';",
            1
        )
    print('FIX 4: client_screens.dart - added client_create.dart import for ClientCreateScreen2')

with open(cl, 'w', encoding='utf-8') as f:
    f.write(content)
print('FIX 4: client_screens.dart - added coa_screens + client_create imports')

print('')
print('DONE - run: flutter analyze 2>&1 | Select-String "error" | Measure-Object')
