#!/bin/sh
# Laptop mic (ALC285) clean level: Capture 23 = 0 dB, no boost.
# Higher (Capture 63 + Boost) clips into "old radio" noise. Apps' auto-gain (Discord AGC) pushes it up.
amixer -c Generic_1 -q sset Capture 23
amixer -c Generic_1 -q sset 'Internal Mic Boost' 0
