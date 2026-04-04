import os

m = r'C:\apex_app\apex_finance\lib\main.dart'
with open(m, 'r', encoding='utf-8-sig') as f:
    lines = f.readlines()

print('Before: %d lines' % len(lines))

# Find the orphaned ForgotPasswordScreen fragment in main.dart
# It starts around the line with 'State<ForgotPasswordScreen>'
# and ends just before 'class VerifyResetCodeScreen'
remove_start = None
remove_end = None

for i, line in enumerate(lines):
    if 'State<ForgotPasswordScreen>' in line and remove_start is None:
        remove_start = i
        # Include comment lines above it
        while remove_start > 0 and lines[remove_start - 1].strip().startswith('//'):
            remove_start -= 1
    if remove_start is not None and remove_end is None:
        if 'class VerifyResetCodeScreen' in line:
            remove_end = i
            break

if remove_start is not None and remove_end is not None:
    removed = lines[remove_start:remove_end]
    print('Removing L%d to L%d (%d lines)' % (remove_start + 1, remove_end, len(removed)))
    for r in removed[:3]:
        print('  ' + r.rstrip())
    print('  ...')
    del lines[remove_start:remove_end]
    print('Removed orphaned ForgotPasswordScreen fragment')
else:
    print('WARNING: Could not find ForgotPasswordScreen fragment boundaries')

# Clean ForgotPasswordScreen comment from subscription_screens.dart
s = r'C:\apex_app\apex_finance\lib\screens\extracted\subscription_screens.dart'
with open(s, 'r', encoding='utf-8') as f:
    slines = f.readlines()
before_count = len(slines)
slines = [l for l in slines if 'ForgotPasswordScreen' not in l]
after_count = len(slines)
with open(s, 'w', encoding='utf-8') as f:
    f.writelines(slines)
print('Cleaned subscription_screens.dart: removed %d line(s)' % (before_count - after_count))

# Check if forgot_password_flow.dart import exists in main.dart
has_import = any('forgot_password_flow' in l for l in lines)
if not has_import:
    last_imp = 0
    for i, l in enumerate(lines):
        if l.strip().startswith('import '):
            last_imp = i
    imp_line = "import 'screens/auth/forgot_password_flow.dart';\n"
    lines.insert(last_imp + 1, imp_line)
    print('Added import for forgot_password_flow.dart')
else:
    print('Import for forgot_password_flow.dart already exists')

with open(m, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print('After: %d lines' % len(lines))
print('DONE')
