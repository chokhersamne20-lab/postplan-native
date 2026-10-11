#!/usr/bin/env bash
# android/app/src/main/AndroidManifest.xml-এ প্রয়োজনীয় পারমিশন/রিসিভার যোগ (idempotent)
set -euo pipefail

python3 - <<'PYEOF'
p = 'android/app/src/main/AndroidManifest.xml'
s = open(p, encoding='utf-8').read()

PERMS = '''
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FLASHLIGHT"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
'''

RECEIVERS = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
        </receiver>
        <receiver android:exported="true" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
'''

changed = False
if 'POST_NOTIFICATIONS' not in s:
    s = s.replace('<application', PERMS + '    <application', 1)
    changed = True
if 'ScheduledNotificationReceiver' not in s:
    s = s.replace('</application>', RECEIVERS + '    </application>', 1)
    changed = True

open(p, 'w', encoding='utf-8').write(s)
print('manifest patched' if changed else 'manifest already ok')
PYEOF
