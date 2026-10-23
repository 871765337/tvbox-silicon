# QR codes for the TestFlight invites in src/components/controls.tsx (TESTFLIGHT).
# Run from website/ after changing a link: uv run --with segno scripts/testflight-qr.py
import re

import segno

links = dict(re.findall(r'(ios|tv): "(https://testflight\.apple\.com/join/\w+)"', open("src/components/controls.tsx").read()))
assert set(links) == {"ios", "tv"}, links
for name, url in links.items():
    path = f"public/testflight/{name}.svg"
    segno.make(url, error="m", micro=False).save(path, kind="svg", border=0, dark="#1d1d1f", light=None, xmldecl=False, nl=False)
    # Scale with the <img> (a viewBox instead of a fixed size) and keep the modules sharp.
    svg = open(path).read()
    svg = re.sub(r'width="(\d+)" height="\1"', r'viewBox="0 0 \1 \1" shape-rendering="crispEdges"', svg, count=1)
    open(path, "w").write(svg)
    print(path, url)
