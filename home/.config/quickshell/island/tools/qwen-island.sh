#!/usr/bin/env bash
# The local model (Qwen in LM Studio) edits a COPY of Island, never the live files.
# The copy is a git worktree of the live Island repo: ~/Documents/qwen-work/island (branch "qwen").
#   qwen-island            = status: what the model changed (diff)
#   qwen-island apply MSG  show the change, ask, then make it live as one commit (Island reloads by itself)
#   qwen-island discard    throw the model's changes away
#   qwen-island sync       refresh the copy from live Island (apply / discard do this too)
#   qwen-island undo       undo the last commit on live Island (git revert, asks first)
set -euo pipefail
LIVE="$HOME/.config/quickshell/island"
WORK="$HOME/Documents/qwen-work/island"
g() { git -C "$LIVE" "$@"; }
w() { git -C "$WORK" "$@"; }
ask() { read -r -p "$1 [y/N] " a; [ "$a" = y ] || [ "$a" = Y ]; }

# live edits that were never committed (by hand, Claude, …) are saved first, so the copy always starts from what runs now
save_live() { [ -z "$(g status --porcelain)" ] || { g add -A; g commit -qm "chore: save live edits"; }; }
sync() { save_live; w reset -q --hard main; w clean -qfd; }
[ -e "$WORK/.git" ] || { mkdir -p "${WORK%/*}"; save_live; g worktree add -q -B qwen "$WORK" main; }

case "${1:-status}" in
status)
    if [ -z "$(w status --porcelain)" ]; then echo "The model changed nothing."; exit 0; fi
    w status --short; echo; w --no-pager diff ;;
apply)
    msg="${2:-}"; [ -n "$msg" ] || { echo 'Usage: qwen-island apply "fix(island): what changed"'; exit 1; }
    [ -n "$(w status --porcelain)" ] || { echo "The model changed nothing."; exit 0; }
    w status --short; echo; w --no-pager diff
    # a QML syntax error would keep the old Island running and hide the change; refuse it
    bad=""; for f in $(w diff --name-only -- '*.qml') $(w ls-files --others --exclude-standard -- '*.qml'); do
        out=$(/usr/lib/qt6/bin/qmllint "$WORK/$f" 2>&1 | grep -iE 'syntax error|Expected token|Unexpected token' || true)
        [ -z "$out" ] || bad="$bad$f: $out"$'\n'
    done
    [ -z "$bad" ] || { echo; echo "Not applied — QML syntax errors:"; echo "$bad"; exit 1; }
    ask "Make this live?" || { echo "Not applied (still in the copy)."; exit 0; }
    save_live
    w add -A; w commit -qm "$msg"
    if g merge -q --ff-only qwen 2>/dev/null; then echo "Live: $msg"
    else g cherry-pick qwen >/dev/null && echo "Live: $msg"; fi
    sync ;;
discard) ask "Throw the model's changes away?" && { sync; echo "Copy reset to live Island."; } ;;
sync) sync; echo "Copy matches live Island." ;;
undo)
    g --no-pager log -1 --format='Last change: %h %s'
    ask "Undo it on live Island?" && { g revert --no-edit HEAD >/dev/null; sync; echo "Undone."; } ;;
*) sed -n '2,8p' "$0"; exit 1 ;;
esac
