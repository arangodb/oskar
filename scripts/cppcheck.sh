#!/bin/sh
set -e

cd /work/ArangoDB
./utils/cppcheck.sh -j $PARALLELISM
