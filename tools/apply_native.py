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
            '            android:stopWithTask="true"\n'
            '            android:foregroundServiceType="mediaPlayback"/>\n'
        )
        xml = xml.replace("</application>", service + "    </application>")

    with open(manifest, "w", encoding="utf-8") as f:
        f.write(xml)
    print("patched AndroidManifest.xml (permissions + PlaybackService)")

    # compileSdk 상향 — 최신 플러그인(flutter_plugin_android_lifecycle 등)이
    # compileSdk 36 이상을 요구. 생성된 build.gradle(.kts) 의 값을 36으로 고정.
    for gname in ("build.gradle.kts", "build.gradle"):
        gpath = os.path.join(ROOT, "android", "app", gname)
        if not os.path.exists(gpath):
            continue
        with open(gpath, "r", encoding="utf-8") as f:
            g = f.read()
        g2 = re.sub(r"compileSdk\s*=\s*flutter\.compileSdkVersion",
                    "compileSdk = 36", g)  # Kotlin DSL
        g2 = re.sub(r"compileSdkVersion\s+flutter\.compileSdkVersion",
                    "compileSdkVersion 36", g2)  # Groovy
        if g2 != g:
            with open(gpath, "w", encoding="utf-8") as f:
                f.write(g2)
            print(f"patched android/app/{gname} (compileSdk = 36)")
        break

    # 앱 아이콘(생성된 mipmap 덮어쓰기 + 적응형 아이콘)
    icon_src = os.path.join(ROOT, "assets", "launcher_icons", "android")
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    if os.path.isdir(icon_src):
        for dpi in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
            srcdir = os.path.join(icon_src, f"mipmap-{dpi}")
            dstdir = os.path.join(res, f"mipmap-{dpi}")
            os.makedirs(dstdir, exist_ok=True)
            # 레거시 아이콘(< API 26)
            leg = os.path.join(srcdir, "ic_launcher.png")
            if os.path.exists(leg):
                shutil.copy(leg, os.path.join(dstdir, "ic_launcher.png"))
                shutil.copy(leg, os.path.join(dstdir, "ic_launcher_round.png"))
            # 적응형 전경(API 26+)
            fg = os.path.join(srcdir, "ic_launcher_foreground.png")
            if os.path.exists(fg):
                shutil.copy(fg, os.path.join(dstdir, "ic_launcher_foreground.png"))
        print("overwrote Android launcher icons (mipmap-* + adaptive foreground)")

        # 적응형 아이콘 XML(mipmap-anydpi-v26) + 배경색.
        anydpi = os.path.join(res, "mipmap-anydpi-v26")
        os.makedirs(anydpi, exist_ok=True)
        adaptive_xml = (
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '</adaptive-icon>\n'
        )
        for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
            with open(os.path.join(anydpi, name), "w", encoding="utf-8") as f:
                f.write(adaptive_xml)
        # 배경색 리소스(#0F1017, generate_app_icon.ADAPTIVE_BG 와 동일)
        values = os.path.join(res, "values")
        os.makedirs(values, exist_ok=True)
        colors = os.path.join(values, "colors.xml")
        color_line = '    <color name="ic_launcher_background">#0F1017</color>\n'
        if os.path.exists(colors):
            with open(colors, "r", encoding="utf-8") as f:
                cx = f.read()
            if "ic_launcher_background" not in cx:
                cx = cx.replace("</resources>", color_line + "</resources>")
                with open(colors, "w", encoding="utf-8") as f:
                    f.write(cx)
        else:
            with open(colors, "w", encoding="utf-8") as f:
                f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                        + color_line + '</resources>\n')
        print("wrote adaptive-icon XML + background color")


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

    # AVAudioSourceNode 는 iOS 13+ 필요 → 배포 타깃 상향(기본 12.0).
    pbxproj = os.path.join(ROOT, "ios", "Runner.xcodeproj", "project.pbxproj")
    if os.path.exists(pbxproj):
        with open(pbxproj, "r", encoding="utf-8") as f:
            pb = f.read()
        for old in ("IPHONEOS_DEPLOYMENT_TARGET = 12.0;",
                    "IPHONEOS_DEPLOYMENT_TARGET = 11.0;"):
            pb = pb.replace(old, "IPHONEOS_DEPLOYMENT_TARGET = 13.0;")
        with open(pbxproj, "w", encoding="utf-8") as f:
            f.write(pb)
        print("patched project.pbxproj (IPHONEOS_DEPLOYMENT_TARGET = 13.0)")

    # 앱 아이콘(AppIcon.appiconset 전체 교체)
    icon_src = os.path.join(ROOT, "assets", "launcher_icons", "ios", "AppIcon.appiconset")
    icon_dst = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.isdir(icon_src) and os.path.isdir(os.path.dirname(icon_dst)):
        shutil.rmtree(icon_dst, ignore_errors=True)
        shutil.copytree(icon_src, icon_dst)
        print("replaced iOS AppIcon.appiconset")

    podfile = os.path.join(ROOT, "ios", "Podfile")
    if os.path.exists(podfile):
        lines = []
        set_platform = False
        with open(podfile, "r", encoding="utf-8") as f:
            for line in f:
                stripped = line.strip()
                if stripped.startswith("platform :ios") or \
                   stripped.startswith("# platform :ios"):
                    lines.append("platform :ios, '13.0'\n")
                    set_platform = True
                else:
                    lines.append(line)
        if not set_platform:
            lines.insert(0, "platform :ios, '13.0'\n")
        with open(podfile, "w", encoding="utf-8") as f:
            f.writelines(lines)
        print("patched Podfile (platform :ios, '13.0')")


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
