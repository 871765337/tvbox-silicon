#!/bin/bash
# Fail when a packaged Java host was built from older converter sources than this checkout.
# Xcode copies build/JavaHost (Mac) and build/AppleRuntime/<platform>/Resources/JavaHost (iPhone, Apple TV) into
# the app without rebuilding them, so a stale copy ships its old DEX converter: in October 2026 a host-v13 copy
# left 玩偶哥哥 and the other sources of the 2026-10-21 FTY jar empty on every device, though main had the fix.
# BytecodeCompatibility.VERSION goes up whenever conversion changes; the packaged host must carry the same one.
# Usage: Scripts/check-java-host.sh <host.jar>...
set -euo pipefail
source="$(dirname "$0")/../Runtime/JavaHost/src/main/java/tvbox/runtime/BytecodeCompatibility.java"
want=$(sed -n 's/.*String VERSION = "\(host-v[0-9]*\)".*/\1/p' "$source")
if [ -z "$want" ]; then echo "error: BytecodeCompatibility.VERSION not found" >&2; exit 1; fi
status=0
for jar in "$@"; do
  got=$(unzip -p "$jar" tvbox/runtime/BytecodeCompatibility.class 2>/dev/null | grep -a -o 'host-v[0-9]*' | head -1 || true)
  if [ "$got" != "$want" ]; then
    echo "error: $jar is Java host ${got:-unknown}, but the sources are $want. Rebuild it: Scripts/build-java-host.sh, then Scripts/sync-apple-javahost.sh." >&2
    status=1
  fi
done
exit $status
