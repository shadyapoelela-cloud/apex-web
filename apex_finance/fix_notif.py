import os, shutil
BASE = r"C:\apex_app\apex_finance\lib"
MAIN = os.path.join(BASE, "main.dart")
shutil.copy2(MAIN, MAIN + ".bak_notif")
print("[OK] Backup done")
f = open(MAIN, "r", encoding="utf-8-sig")
lines = f.readlines()
f.close()
print(f"[i] main.dart: {len(lines)} lines")
imp = "import 'screens/notification/notification_screens.dart' as notif;\n"
for i, line in enumerate(lines):
    if "subscription_screens.dart" in line and "import" in line:
        lines.insert(i+1, imp)
        print(f"[OK] Import added at line {i+2}")
        break
else:
    for i, line in enumerate(lines):
        if "audit_service_screen.dart" in line and "import" in line:
            lines.insert(i+1, imp)
            print(f"[OK] Import added at line {i+2} (fallback)")
            break
reps = 0
rep_map = {"NotificationCenterScreenV2()": "notif.NotificationCenterScreenV2()", "NotificationPrefsScreen()": "notif.NotificationPrefsScreen()"}
for i, line in enumerate(lines):
    if "notification_screens.dart" in line: continue
    n = line
    for old, new in rep_map.items():
        if old in n and "class " not in n:
            n = n.replace(old, new)
            if n != line: reps += 1
    lines[i] = n
print(f"[OK] Replaced {reps} references")
sd = ed = None
for i, line in enumerate(lines):
    if "// NotificationCenterScreen" in line and chr(1575) in line:
        sd = i
        if i > 0 and chr(9552) in lines[i-1]: sd = i-1
        if sd > 0 and chr(9552) in lines[sd-1]: sd = sd-1
        break
for i, line in enumerate(lines):
    if "class LegalDocumentsScreenV2" in line:
        ed = i
        while ed > 0 and (chr(9552) in lines[ed-1] or ("// " in lines[ed-1] and "Legal" in lines[ed-1]) or lines[ed-1].strip() == ""):
            ed -= 1
        break
if sd and ed:
    rm = ed - sd
    del lines[sd:ed]
    print(f"[OK] Removed {rm} old lines")
else:
    print(f"[WARN] sd={sd} ed={ed}")
f = open(MAIN, "w", encoding="utf-8")
f.write("".join(lines))
f.close()
print(f"[OK] DONE! main.dart: {len(lines)} lines now")