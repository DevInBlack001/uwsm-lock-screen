#!/usr/bin/env bash
# Bounded, argument-list-only HTTPS download with Content-Type validation.

wp_fetch_url() {
  local url="$1" dest="$2"
  local content_type
  content_type="$(curl --proto '=https,http' --max-filesize 20971520 --max-time 15 \
    -sS -L -o "$dest" -w '%{content_type}' -- "$url" 2>/dev/null)"
  local curl_status=$?

  if [[ $curl_status -ne 0 ]]; then
    rm -f "$dest"
    return 1
  fi

  if [[ ! -s "$dest" ]]; then
    rm -f "$dest"
    return 1
  fi

  case "$content_type" in
    image/png*|image/jpeg*|image/webp*) ;;
    *)
      rm -f "$dest"
      return 1
      ;;
  esac

  return 0
}
