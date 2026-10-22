#!/bin/sh
# Test the Isla login screen without logging out. Run after `sudo pacman -Syu` (Hyprland / quickshell updates)
# and after changing Isla's lock screen, BEFORE you reboot.
#   ./check.sh          test the installed login screen (what you will see at boot)
#   ./check.sh --fresh  test a fresh build from your current Isla files (before running install.sh)
# A small window opens for ~10 s: it logs in by itself against a pretend greetd.
here="$(cd "$(dirname "$0")" && pwd)"
share=/usr/local/share/isla-greeter
data=/var/lib/isla-greeter
work=$(mktemp -d /tmp/isla-greeter-check.XXXXXX)
fails=0; warns=0
ok()   { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fails=$((fails + 1)); }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$1"; warns=$((warns + 1)); }

sh "$here/build.sh" "$work/build" >/dev/null 2>&1 || bad "build.sh failed"
target="$share"; [ "${1:-}" = "--fresh" ] && target="$work/build"
echo "Testing: $target"

echo "1. programs"
for p in Hyprland qs hyprctl agreety uwsm dbus-run-session; do
    command -v "$p" >/dev/null && ok "$p found" || bad "$p missing"
done
[ -f /usr/share/wayland-sessions/hyprland.desktop ] && ok "hyprland.desktop session exists" || bad "/usr/share/wayland-sessions/hyprland.desktop missing"
echo "   Hyprland $(Hyprland --version 2>/dev/null | head -1 | cut -c1-40) · $(qs --version 2>/dev/null)"

echo "2. greetd setup"
if grep -q "isla-greeter-session" /etc/greetd/config.toml 2>/dev/null; then ok "greetd uses the Isla login screen"
else warn "greetd does not use the Isla login screen (not installed?)"; fi
grep -q '^\[initial_session\]' /etc/greetd/config.toml 2>/dev/null && warn "auto-login is still on" || ok "no auto-login"
[ -x "$share/isla-greeter-session" ] && ok "installed" || bad "not installed: sudo $here/install.sh"

echo "3. installed copy is up to date"
if diff -rq "$work/build" "$share" >"$work/diff" 2>&1; then ok "same as your current Isla files"
else warn "installed copy differs from your Isla files → sudo $here/install.sh"; sed 's/^/        /' "$work/diff" | head -5; fi

echo "4. the greeter user can read everything"
unread=$(find "$target" ! -perm -o=r 2>/dev/null | head -3)
[ -z "$unread" ] && ok "login screen files readable" || bad "not readable by greeter: $unread"
for f in prefs.json screens user.json; do
    [ -r "$data/$f" ] && [ -n "$(find "$data/$f" -perm -o=r)" ] && ok "$data/$f" || bad "$data/$f missing or not readable"
done
[ "$(stat -c %U "$data/home" 2>/dev/null)" = greeter ] && ok "greeter home folder" || bad "$data/home missing / wrong owner"
systemctl --user is-active -q isla-greeter-sync.path && ok "look auto-update is on" || warn "systemctl --user enable --now isla-greeter-sync.path"

echo "5. Hyprland accepts greeter.lua"
if Hyprland --verify-config -c "$target/greeter.lua" 2>&1 | grep -q "config ok"; then ok "config ok"
else bad "greeter.lua has errors:"; Hyprland --verify-config -c "$target/greeter.lua" 2>&1 | grep -v '^>' | tail -5 | sed 's/^/        /'; fi

echo "6. full login (window opens ~10 s, logs in by itself)"
rt="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
rm -f "$rt/isla-greeter-ok" "$rt/isla-greeter-qs.log"
python3 -I "$here/fake-greetd.py" "$work/greetd.sock" "$work/greetd.json" &
fpid=$!
sleep 0.5
start=$(date +%s)
GREETD_SOCK="$work/greetd.sock" ISLA_GREETER_TEST=1 ISLA_GREETER_SHARE="$target" ISLA_GREETER_DATA="$data" \
    timeout 45 Hyprland -c "$target/greeter.lua" >"$work/hyprland.log" 2>&1
code=$?; took=$(( $(date +%s) - start ))
kill "$fpid" 2>/dev/null; wait "$fpid" 2>/dev/null
[ "$code" = 124 ] && bad "greeter did not finish in 45 s" || ok "greeter closed by itself after ${took} s"
# known + harmless: Quickshell 0.3 cancels the old greetd session itself before a retry and logs greetd's normal "success" reply as unexpected
if grep -E "ERROR|is not a type|unavailable|ReferenceError|TypeError" "$rt/isla-greeter-qs.log" 2>/dev/null \
    | grep -v 'unexpected greetd response "{\\"type\\": \\"success\\"}"' >"$work/err"; [ -s "$work/err" ]; then
    bad "Quickshell errors:"; head -5 "$work/err" | sed 's/^/        /'
elif [ -s "$rt/isla-greeter-qs.log" ]; then ok "Quickshell loaded the login screen, no errors"
else bad "Quickshell did not start (no log)"; fi
python3 -I - "$work/greetd.json" <<'PY' && ok "wrong password refused, right one logged in, session = isla-session (→ uwsm Hyprland)" || bad "greetd talk not as expected"
import json, sys
got = json.load(open(sys.argv[1]))
types = [g["type"] for g in got]
resp = [g.get("response") for g in got if g["type"] == "post_auth_message_response"]
start = [g for g in got if g["type"] == "start_session"]
print("        greetd saw:", " → ".join(types))
ok = resp[:1] == ["wrong-pass"] and resp[-1:] == ["isla-test"] and len(start) == 1 \
     and len(start[0]["cmd"]) == 1 and start[0]["cmd"][0].endswith("/isla-session")
sys.exit(0 if ok else 1)
PY
[ -e "$rt/isla-greeter-ok" ] && ok "login marker written (no text-login fallback)" || bad "login marker missing (boot would fall back to text login)"
rm -f "$rt/isla-greeter-ok"

echo "7. safety net (text login if the greeter breaks)"
mkdir -p "$work/bin" "$work/data/home" "$work/rt"
printf '#!/bin/sh\necho agreety >"%s/fallback"\n' "$work" >"$work/bin/agreety"
printf '#!/bin/sh\nexit 1\n' >"$work/bin/Hyprland"
chmod +x "$work/bin/"*
PATH="$work/bin:$PATH" XDG_RUNTIME_DIR="$work/rt" ISLA_GREETER_SHARE="$target" ISLA_GREETER_DATA="$work/data" sh "$target/isla-greeter-session" >/dev/null 2>&1
[ -e "$work/fallback" ] && ok "broken greeter → text login" || bad "broken greeter does NOT fall back to text login"
rm -f "$work/fallback"
printf '#!/bin/sh\ntouch "$XDG_RUNTIME_DIR/isla-greeter-ok"\n' >"$work/bin/Hyprland"
PATH="$work/bin:$PATH" XDG_RUNTIME_DIR="$work/rt" ISLA_GREETER_SHARE="$target" ISLA_GREETER_DATA="$work/data" sh "$target/isla-greeter-session" >/dev/null 2>&1
[ ! -e "$work/fallback" ] && ok "good login → no text login" || bad "text login shown even after a good login"

echo
if [ "$fails" = 0 ]; then
    printf '\033[32mAll good\033[0m (%s warnings). Safe to reboot.\n' "$warns"; rm -rf "$work"; exit 0
else
    printf '\033[31m%s problem(s).\033[0m Do not reboot yet. Logs: %s  (undo: sudo %s/uninstall.sh)\n' "$fails" "$work" "$here"; exit 1
fi
