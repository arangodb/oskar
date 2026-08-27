#!/bin/sh
set -e

# cppcheck comes from the Alpine package (2.21.x on alpine:3.24) instead of
# a source compile: oskar never uses the --rule feature the old
# HAVE_RULES=yes build existed for, and the pinned source tree kept
# breaking against new toolchains (2.10 no longer compiled at all).
apk update
apk add groff fish bash python3 cppcheck

cppcheck --version
