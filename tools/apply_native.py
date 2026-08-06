#!/usr/bin/env python3
"""`flutter create` 로 생성된 플랫폼 스캐폴드 위에 마인드사운드 네이티브 오디오 엔진을
오버레이한다. CI에서 android/ios 빌드 전에 실행.

- Android: native/android/*.kt 를 생성된 kotlin 소스 디렉터리에 복사(MainActivity 덮어쓰기),
  AndroidManifest.xml 에 권한/서비스 추가.
- iOS: native/ios/AppDelegate.swift 로 Runner/AppDelegate.swift 덮어쓰기,
  Info.plist 에 UIBackgroundModes(audio) 추가.
"""
import argparse
import os
import re
import shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PKG_PATH = "com/mindsound/mindsound"


def apply_android():
    src = os.path.join(ROOT, "native", "android")
    dst = os.path.join(ROOT, "android", "app", "src", "main", "kotlin", *PKG_PATH.split("/"))
    os.makedirs(dst, exist_ok=True)
    for name in os.listdir(src):
        if name.endswith(".kt"):
            shutil.copy(os.path.join(src, name), os.path.join(dst, name))
            print(f"copied {name} -> {dst}")

    manifest = os.path.join(ROOT, "android", "app", "src", "main", "AndroidManifest.xml")
    with open(manifest, "r", encoding="utf-8") as f:
        xml = f.read()

    perms = [
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
        "android.permission.WAKE_LOCK",
        "android.permission.POST_NOTIFICATIONS",
    ]
    perm_xml = "\n".join(
        f'    <uses-permission android:name="{p}"/>' for p in perms
        if p not in xml
    )
    if perm_xml:
        xml = re.sub(r"(<manifest[^>]*>)", r"\1\n" + perm_xml, xml, count=1)

    if "PlaybackService" not in xml:
        service = (
            '        <service\n'
            '            android:name=".PlaybackService"\n'
            '            android:exported="false"\n'
            '            android:foregroundServiceType="mediaPlayback"/>\n'
        )
        xml = xml.replace("</application>", service + "    </application>")

    with open(manifest, "w", encoding="utf-8") as f:
        f.write(xml)
    print("patched AndroidManifest.xml (permissions + PlaybackService)")


def apply_ios():
    src = os.path.join(ROOT, "native", "ios", "AppDelegate.swift")
    dst = os.path.join(ROOT, "ios", "Runner", "AppDelegate.swift")
    shutil.copy(src, dst)
    print(f"overwrote {dst}")

    plist = os.path.join(ROOT, "ios", "Runner", "Info.plist")
    with open(plist, "r", encoding="utf-8") as f:
        content = f.read()
    if "UIBackgroundModes" not in content:
        insert = (
            "\t<key>UIBackgroundModes</key>\n"
            "\t<array>\n\t\t<string>audio</string>\n\t</array>\n"
        )
        content = content.replace("</dict>\n</plist>", insert + "</dict>\n</plist>", 1)
        with open(plist, "w", encoding="utf-8") as f:
            f.write(content)
        print("patched Info.plist (UIBackgroundModes: audio)")
    else:
        print("Info.plist already has UIBackgroundModes")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--platform", choices=["android", "ios", "both"], default="both")
    args = ap.parse_args()
    if args.platform in ("android", "both"):
        apply_android()
    if args.platform in ("ios", "both"):
        apply_ios()


if __name__ == "__main__":
    main()
