#!/bin/sh
echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/main" >> /etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/community" >> /etc/apk/repositories
wget -q -O /etc/apk/keys/alpine-devel@lists.alpinelinux.org-4a6a0840.rsa.pub https://raw.githubusercontent.com/alpinelinux/aports/946af5ada94736faeea91d06f3fb685eb6b4adb3/main/alpine-keys/alpine-devel@lists.alpinelinux.org-4a6a0840.rsa.pub
wget -q -O /etc/apk/keys/alpine-devel@lists.alpinelinux.org-6165ee59.rsa.pub https://raw.githubusercontent.com/alpinelinux/aports/946af5ada94736faeea91d06f3fb685eb6b4adb3/main/alpine-keys/alpine-devel@lists.alpinelinux.org-6165ee59.rsa.pub
wget -q -O /etc/apk/keys/alpine-devel@lists.alpinelinux.org-5243ef4b.rsa.pub https://raw.githubusercontent.com/alpinelinux/aports/946af5ada94736faeea91d06f3fb685eb6b4adb3/main/alpine-keys/alpine-devel@lists.alpinelinux.org-5243ef4b.rsa.pub
wget -q -O /etc/apk/keys/alpine-devel@lists.alpinelinux.org-61666e3f.rsa.pub https://raw.githubusercontent.com/alpinelinux/aports/946af5ada94736faeea91d06f3fb685eb6b4adb3/main/alpine-keys/alpine-devel@lists.alpinelinux.org-61666e3f.rsa.pub
wget -q -O /etc/apk/keys/alpine-devel@lists.alpinelinux.org-5261cecb.rsa.pub https://raw.githubusercontent.com/alpinelinux/aports/946af5ada94736faeea91d06f3fb685eb6b4adb3/main/alpine-keys/alpine-devel@lists.alpinelinux.org-5261cecb.rsa.pub
apk update
