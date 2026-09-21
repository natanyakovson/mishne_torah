#!/bin/sh
set -eu
fail() { echo "error: Supabase configuration: $1" >&2; exit 1; }
url="${INFOPLIST_KEY_MTSupabaseProjectURL:-}"
key="${SUPABASE_PUBLISHABLE_KEY:-}"
case "$url" in
  https://*.supabase.co) ;;
  *) fail "missing/invalid production HTTPS project URL" ;;
esac
case "$key" in
  sb_publishable_?*) ;;
  eyJ*.*.*)
    payload=$(printf '%s' "$key" | cut -d . -f 2 | tr '_-' '/+')
    case $((${#payload} % 4)) in 2) payload="$payload==" ;; 3) payload="$payload=" ;; esac
    role=$(printf '%s' "$payload" | /usr/bin/base64 -D | /usr/bin/plutil -extract role raw -o - - 2>/dev/null) || fail "invalid anon JWT"
    [ "$role" = anon ] || fail "only publishable/anon keys are permitted"
    ;;
  *) fail "set SUPABASE_PUBLISHABLE_KEY in ignored Config/Local.xcconfig; secret/service-role keys are forbidden" ;;
esac
echo "Supabase production URL and public key validated (key not logged)."
