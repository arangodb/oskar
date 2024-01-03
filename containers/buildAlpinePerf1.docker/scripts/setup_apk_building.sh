#!/bin/sh
apk add alpine-sdk
adduser -D arangodb
addgroup arangodb abuild
mkdir -p /var/cache/distfiles
chmod a+w /var/cache/distfiles
chgrp abuild /var/cache/distfiles
chmod g+w /var/cache/distfiles
su - arangodb /scripts/user_specific_setup.sh
mkdir -p /etc/apk/keys
cp -a /home/arangodb/.abuild/*.pub /etc/apk/keys

