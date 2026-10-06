#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/wallpaper-fetch.sh"

FAILURES=0
assert_status() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $desc (expected exit $expected, got $actual)"
    FAILURES=$((FAILURES + 1))
  fi
}
assert_file_exists() {
  local desc="$1" path="$2"
  if [[ ! -f "$path" ]]; then
    echo "FAIL: $desc ($path does not exist)"
    FAILURES=$((FAILURES + 1))
  fi
}
assert_file_absent() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "FAIL: $desc ($path should not exist)"
    FAILURES=$((FAILURES + 1))
  fi
}

TMPDIR_TEST="$(mktemp -d)"
trap 'kill $SERVER_PID 2>/dev/null; rm -rf "$TMPDIR_TEST"' EXIT

# Serve a tiny fixed-content "image" and an "error page" from a local HTTP
# server, so the test never depends on network access.
mkdir -p "$TMPDIR_TEST/www"
printf '\x89PNG\r\n\x1a\nFAKE_PNG_BYTES' > "$TMPDIR_TEST/www/good.png"
printf '<html>not an image</html>' > "$TMPDIR_TEST/www/bad.html"

cat > "$TMPDIR_TEST/server.py" <<'PYEOF'
import http.server, os, sys
os.chdir(sys.argv[2])
class Handler(http.server.SimpleHTTPRequestHandler):
    def guess_type(self, path):
        if path.endswith(".png"):
            return "image/png"
        return "text/html"
http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
PYEOF

# No subshell wrapper around this - $! must be the actual server process's
# PID so the EXIT trap can kill it. An earlier version wrapped this in
# `(cd dir && python3 ...) &`, which made $! the subshell's PID instead,
# leaving python3 itself as an orphaned grandchild that kept the port bound
# across every subsequent test run (diagnosed via `ss -tlnp` showing a
# stale listener from a prior run serving from an already-deleted tmpdir).
PORT=18532
python3 "$TMPDIR_TEST/server.py" "$PORT" "$TMPDIR_TEST/www" >/dev/null 2>&1 &
SERVER_PID=$!
sleep 0.5

# Success case: real PNG content-type
DEST_OK="$TMPDIR_TEST/out-ok.png"
set +e
wp_fetch_url "http://127.0.0.1:$PORT/good.png" "$DEST_OK"
assert_status "fetch succeeds for image content-type" 0 $?
set -e
assert_file_exists "downloaded file kept on success" "$DEST_OK"

# Failure case: wrong content-type must be rejected and cleaned up
DEST_BAD="$TMPDIR_TEST/out-bad.png"
set +e
wp_fetch_url "http://127.0.0.1:$PORT/bad.html" "$DEST_BAD"
assert_status "fetch rejects non-image content-type" 1 $?
set -e
assert_file_absent "rejected download is deleted" "$DEST_BAD"

# Failure case: nonexistent path (connection works, 404)
DEST_404="$TMPDIR_TEST/out-404.png"
set +e
wp_fetch_url "http://127.0.0.1:$PORT/missing.png" "$DEST_404"
assert_status "fetch rejects 404" 1 $?
set -e
assert_file_absent "404 download is deleted" "$DEST_404"

if [[ $FAILURES -eq 0 ]]; then
  echo "test-wallpaper-fetch.sh: all assertions passed"
else
  echo "test-wallpaper-fetch.sh: $FAILURES assertion(s) failed"
  exit 1
fi
