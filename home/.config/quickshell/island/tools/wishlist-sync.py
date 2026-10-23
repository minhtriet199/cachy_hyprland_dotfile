#!/usr/bin/env python3
# Copies the "Rice wish list" to-do board into the handoff doc (RICE-HANDOFF.md §8b, between the wishlist markers).
# The board is the one to edit; Island runs this after every save of that board (SvcTodo.qml), dotfiles-sync too.
import os, re

H = os.path.expanduser("~")
BOARD = H + "/Documents/Todo/Rice wish list.md"
DOC = H + "/Documents/Md_File/RICE-HANDOFF.md"
START = "<!-- wishlist:start — copied from ~/Documents/Todo/Rice wish list.md (Island ✓ card): edit the board, not this -->"
END = "<!-- wishlist:end -->"

try:
    board = open(BOARD).read()
    doc = open(DOC).read()
except OSError:
    raise SystemExit(0)
items = [l for l in board.splitlines() if re.match(r"^(- \[[ xX]\] |\s+- \[)", l)]
block = START + "\n" + "\n".join(items) + "\n" + END
new = re.sub(re.escape(START) + r".*?" + re.escape(END), lambda m: block, doc, flags=re.S)
if new != doc:
    open(DOC + ".part", "w").write(new)
    os.replace(DOC + ".part", DOC)
