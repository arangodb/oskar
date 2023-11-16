#!/bin/sh
su - arangodb /scripts/build_glibc_string_user.sh
apk add /home/arangodb/packages/core/*/*.apk
#rm -rf /home/arangodb/packages/core
