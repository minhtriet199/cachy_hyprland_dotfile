#!/bin/sh
# Self-test for the Hyprland + Island scripts. Safe to run any time: nothing touches the real desktop or real settings —
# hyprctl / notify-send are replaced by fakes and every script runs against a throwaway HOME.
#   ~/.config/hypr/tests/run.sh
# 1. hypr-check.sh (Lua syntax, --verify-config, configerrors, Python syntax, needed tools)
# 2. --verify-config really catches a bad option (on a copy of the config)
# 3. screenctl / inputctl / lookctl: a change Hyprland rejects is rolled back and nothing broken is saved
# 4. appearance/timelang put(): unchanged = no write, changed = backup + atomic replace
S=$HOME/.config/hypr/scripts
I=$HOME/.config/quickshell/island
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fails=0
ok()   { echo "  ok    $1"; }
fail() { echo "  FAIL  $1"; fails=$((fails + 1)); }

echo "1. setup check"
if out=$("$S/hypr-check.sh" 2>&1); then ok "hypr-check"; else
    echo "$out" | sed 's/^/        /'
    echo "$out" | grep -vE 'installed only as a dependency|^Hyprland .* → ' | grep -q . && fail "hypr-check" || ok "hypr-check (warnings only)"
fi

echo "2. verify-config catches a bad option"
cp -r "$HOME/.config/hypr" "$T/hypr"
echo 'hl.config({ general = { gaps_inn = 3 } })' >> "$T/hypr/config/look.lua"
Hyprland --verify-config -c "$T/hypr/hyprland.lua" 2>&1 | grep -q "gaps_inn" && ok "bad key reported" || fail "bad key not reported"

echo "3. rollback when Hyprland rejects a change"
mkdir -p "$T/bin" "$T/home/.local/state/hypr"
cat > "$T/bin/hyprctl" <<'EOF'
#!/bin/sh
# fake: reload with "mode=9999" in the screens file → configerrors; eval fails once when $T/evalbad exists
T=$(dirname "$(dirname "$0")")
case "$1" in
  configerrors) [ -e "$T/broken" ] && echo "monitors.lua:3: bad mode" ;;
  reload) if grep -q 'mode=9999' "$T/home/.local/state/hypr/screens" 2>/dev/null; then touch "$T/broken"; else rm -f "$T/broken"; fi; echo ok ;;
  eval) if [ -e "$T/evalbad" ]; then rm -f "$T/evalbad"; echo 'Error: boom'; exit 7; fi; echo ok ;;
  monitors) echo '[{"name":"HDMI-A-1","description":"Fake Mon","make":"","model":"","x":0,"y":0,"width":2560,"height":1440,"scale":1.0,"refreshRate":120.0,"transform":0,"focused":true,"availableModes":["2560x1440@120.00Hz"],"disabled":false}]' ;;
  *) echo ok ;;
esac
EOF
printf '#!/bin/sh\necho "$*" >> "%s/notified"\n' "$T" > "$T/bin/notify-send"
chmod +x "$T/bin/"*
E="env HOME=$T/home PATH=$T/bin:/usr/bin"
SC="$T/home/.local/state/hypr/screens"
printf 'Fake Mon\tmode=2560x1440@120 pos=0x0 scale=1 hdr=0 nits=200 ddc=50 out=HDMI-A-1\n' > "$SC"; cp "$SC" "$T/good"
$E python3 "$S/screenctl.py" mode HDMI-A-1 9999x1440@120 1 >/dev/null 2>&1 && fail "screenctl: bad mode not refused" || ok "screenctl: bad mode refused"
cmp -s "$T/good" "$SC" && ok "screenctl: previous screens file restored" || fail "screenctl: screens file not restored"
[ -e "$T/broken" ] && fail "screenctl: errors left after restore" || ok "screenctl: Hyprland reloaded back to good"
$E python3 "$S/screenctl.py" mode HDMI-A-1 2560x1440@100 1 >/dev/null 2>&1 && grep -q 'mode=2560x1440@100' "$SC" && ok "screenctl: good change saved" || fail "screenctl: good change not saved"
for tool in inputctl lookctl; do
    st="$T/home/.local/state/hypr/$( [ $tool = inputctl ] && echo input || echo look)"
    key=$( [ $tool = inputctl ] && echo sensitivity=0.3 || echo gaps_in=7)
    bad=$( [ $tool = inputctl ] && echo sensitivity=-0.5 || echo gaps_in=9)
    $E python3 "$S/$tool.py" set $key >/dev/null 2>&1; cp "$st" "$T/before" 2>/dev/null
    touch "$T/evalbad"
    $E python3 "$S/$tool.py" set $bad >/dev/null 2>&1 && fail "$tool: rejected change not refused" || ok "$tool: rejected change refused"
    cmp -s "$T/before" "$st" && ok "$tool: saved file unchanged" || fail "$tool: saved file changed"
done
[ "$(grep -c 'not saved\|not applied' "$T/notified" 2>/dev/null)" -ge 3 ] && ok "notifications sent" || fail "notifications missing"

echo "4. put(): backup + atomic replace"
for f in "$I/tools/appearance.py" "$I/tools/timelang.py"; do
    python3 - "$f" "$T/put" <<'EOF' && ok "put() in ${f##*/}" || fail "put() in ${f##*/}"
import os, re, sys
src = open(sys.argv[1]).read()
exec(re.search(r'\ndef put\(.*?\n(?=\n\n)', src, re.S).group(0))
os.makedirs(sys.argv[2], exist_ok=True); p = sys.argv[2] + "/x.ini"
for f in (p, p + ".bak-island"):
    if os.path.exists(f): os.remove(f)
put(p, "one\n"); assert open(p).read() == "one\n" and not os.path.exists(p + ".bak-island")
put(p, "one\n"); assert not os.path.exists(p + ".bak-island")
put(p, "two\n"); assert open(p).read() == "two\n" and open(p + ".bak-island").read() == "one\n"
assert not os.path.exists(p + ".tmp")
EOF
done

echo
[ $fails = 0 ] && echo "All tests passed." || echo "$fails test(s) failed."
[ $fails = 0 ]
