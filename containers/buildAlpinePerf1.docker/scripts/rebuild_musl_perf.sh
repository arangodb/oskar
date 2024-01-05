#!/bin/sh
su - arangodb /scripts/rebuild_musl_perf_user.sh
apk add /home/arangodb/packages/main/*/*.apk
#rm -rf /home/arangodb/packages/main
