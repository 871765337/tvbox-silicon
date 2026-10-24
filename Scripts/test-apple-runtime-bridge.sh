#!/bin/bash
# Test the production Objective-C/JNI bridge on macOS with a real JVM and controlled Java responses.
set -euo pipefail
cd "$(dirname "$0")/.."
JDK="${JAVA_HOME:-$(/usr/libexec/java_home -v 19)}"
OUT="$PWD/build/apple-runtime-bridge-tests"
mkdir -p "$OUT/classes" "$OUT/JavaHost" "$OUT/home/Library/Caches"
"$JDK/bin/javac" --release 17 -d "$OUT/classes" Tests/Java/AppleRuntimeBridge/tvbox/runtime/AppleBootstrap.java
"$JDK/bin/jar" --create --file "$OUT/JavaHost/apple-bindings.jar" -C "$OUT/classes" .
xcrun clang -fobjc-arc -Wall -Wextra -Werror -Wno-unused-parameter \
  -I "$JDK/include" -I "$JDK/include/darwin" \
  Tests/Native/AppleRuntimeBridgeTest.m Runtime/AppleRuntime/Native/AppleRuntime.m \
  -L "$JDK/lib/server" -Wl,-rpath,"$JDK/lib/server" -ljvm -framework Foundation \
  -o "$OUT/AppleRuntimeBridgeTest"
# The bridge sends stderr, and with it failed assertions, to the JVM log; show it on failure.
# Run from $OUT so a JVM crash leaves its hs_err file there, not in the repository.
LOG="$OUT/home/Library/Caches/embedded-jvm.log"
rm -f "$LOG"
(cd "$OUT" && CFFIXED_USER_HOME="$OUT/home" ./AppleRuntimeBridgeTest "$OUT") || { tail -40 "$LOG" 2>/dev/null; exit 1; }
