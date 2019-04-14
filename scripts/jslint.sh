#!/bin/sh
set -e

cd /work/ArangoDB
ARANGOSH=/usr/bin/arangosh ./utils/jslint.sh
