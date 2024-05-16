#!/bin/sh
set -e

# Make some warnings go away:
echo "#include <poll.h>" > /usr/include/sys/poll.h
