#!/usr/bin/env bash
# Bounded, argument-list-only HTTPS download with Content-Type validation.

wp_fetch_url() {
  local url="$1" dest="$2"
  # Tests pass "=http" here to exercise this function against a local
  # plain-HTTP test server (fast, no TLS setup, no network dependency).
  # Production callers never pass this, so they get the secure default:
  # https-only, and --proto-redir keeps any redirect on https too, so an
  # https source can't silently redirect a download down to http.
  local proto="${3:-=https}"
  local tmp_dest="$dest.part"
  local content_type
  content_type="$(curl --proto "$proto" --proto-redir '=https' \
    --max-filesize 20971520 --max-time 15 --fail \
    -sS -L -o "$tmp_dest" -w '%{content_type}' -- "$url" 2>/dev/null)"
  local curl_status=$?

  if [[ $curl_status -ne 0 ]]; then
    rm -f "$tmp_dest"
    return 1
  fi

  if [[ ! -s "$tmp_dest" ]]; then
    rm -f "$tmp_dest"
    return 1
  fi

  case "$content_type" in
    image/png*|image/jpeg*|image/webp*) ;;
    *)
      rm -f "$tmp_dest"
      return 1
      ;;
  esac

  # Atomic: a process kill mid-transfer (omarchy restart shell, Ctrl-C in
  # the TUI) leaves only the .part file, never a truncated file at the
  # final cache path that a later `-s cache_path` check would wrongly
  # treat as already-cached.
  mv -f "$tmp_dest" "$dest"
  return 0
}
