#!/bin/bash
TIMEOUT=360 # in minutes
PORTDIR=/var/tmp/ports

mkdir -p $PORTDIR

if test "$1" == "--clean"; then
    shift

    while test $# -gt 0; do
        echo "freeing port $1"
        rm -f $PORTDIR/$1
        shift
    done

    exit
fi

port=9001
INCR=1

find $PORTDIR -type f -cmin +$TIMEOUT -exec rm "{}" ";"

if test "$1" == "--cluster" ; then
  while ! ((set -o noclobber ; date > $PORTDIR/`expr $port - 1` && \
                               date > $PORTDIR/$port && \
                               date > $PORTDIR/`expr $port + 1` && \
                               date > $PORTDIR/`expr $port + 2` && \
                               date > $PORTDIR/`expr $port + 9` && \
                               date > $PORTDIR/`expr $port + 10` && \
                               date > $PORTDIR/`expr $port + 11` && \
                               date > $PORTDIR/`expr $port + 12` && \
                               date > $PORTDIR/`expr $port + 19` && \
                               date > $PORTDIR/`expr $port + 20` && \
                               date > $PORTDIR/`expr $port + 21` && \
                               date > $PORTDIR/`expr $port + 22`) 2> /dev/null); do
    sleep 1
    port=`expr $port + $INCR`
  done

  echo "$port `expr $port + 10` `expr $port + 20`"
else
  while ! ((set -o noclobber ; date > $PORTDIR/`expr $port - 1` && date > $PORTDIR/$port) 2> /dev/null); do
    sleep 1
    port=`expr $port + $INCR`
  done

  echo $port
fi
