#!/usr/bin/env python3
"""빌드된 Flutter 웹 index.html에 Content-Security-Policy 메타 태그를 주입한다.

정적 호스팅(GitHub Pages 등)은 커스텀 HTTP 헤더를 설정할 수 없으므로,
CSP를 <meta http-equiv> 로 넣어 어떤 호스트에서도 적용되게 한다.

정책은 Flutter CanvasKit 렌더러(gstatic에서 canvaskit 로드) 및 이 앱의
동작(자체 asset fetch, 사용자 음악 blob 재생, Web Audio)을 허용하되,
그 외 외부 출처는 차단한다.
"""
import sys

# 주의: meta 태그에서는 frame-ancestors가 무시된다(실제 헤더에서만 동작).
# 클릭재킹 차단이 필요하면 Vercel 등 실제 헤더 설정(vercel.json)을 사용한다.
CSP = (
    "default-src 'self'; "
    "script-src 'self' 'wasm-unsafe-eval' https://www.gstatic.com; "
    "style-src 'self' 'unsafe-inline'; "
    "img-src 'self' data: blob:; "
    "media-src 'self' blob: data:; "
    "font-src 'self' data:; "
    "connect-src 'self' blob: data: https://www.gstatic.com; "
    "worker-src 'self' blob:; "
    "object-src 'none'; "
    "base-uri 'self'; "
    "form-action 'self'"
)


def main(path: str) -> int:
    with open(path, "r", encoding="utf-8") as f:
        html = f.read()

    if "Content-Security-Policy" in html:
        print("CSP already present, skipping")
        return 0

    meta = f'<meta http-equiv="Content-Security-Policy" content="{CSP}">'
    anchor = '<meta charset="UTF-8">'
    if anchor in html:
        html = html.replace(anchor, anchor + "\n  " + meta, 1)
    else:
        # charset 메타가 없으면 <head> 바로 뒤에 삽입.
        html = html.replace("<head>", "<head>\n  " + meta, 1)

    with open(path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"CSP injected into {path}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: inject_csp.py <index.html>", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
