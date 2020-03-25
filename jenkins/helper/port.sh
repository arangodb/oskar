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

exec 200>/var/lock/$(basename $0)
flock -w 360 200

port=9000
INCR=1

find $PORTDIR -type f -cmin +$TIMEOUT -exec rm "{}" ";"

if test "$1" == "--cluster" ; then
  shift
  while ! ((set -o noclobber ; date > $PORTDIR/$port &&\
                               date > $PORTDIR/`expr $port + 1` &&\
                               date > $PORTDIR/`expr $port + 2` &&\
                               date > $PORTDIR/`expr $port + 3` &&\
                               date > $PORTDIR/`expr $port + 10` &&\
                               date > $PORTDIR/`expr $port + 11` &&\
                               date > $PORTDIR/`expr $port + 12` &&\
                               date > $PORTDIR/`expr $port + 13` &&\
                               date > $PORTDIR/`expr $port + 20` &&\
                               date > $PORTDIR/`expr $port + 21` &&\
                               date > $PORTDIR/`expr $port + 22` &&\
                               date > $PORTDIR/`expr $port + 23`) 2> /dev/null)
  do
    port=`expr $port + $INCR`
  done

  echo "$port `expr $port + 1` `expr $port + 11` `expr $port + 21`"
else
  while ! ((set -o noclobber ; date > $PORTDIR/$port &&\
                               date > $PORTDIR/`expr $port + 1`) 2> /dev/null)
  do
    port=`expr $port + $INCR`
  done

  echo "$port `expr $port + 1`"
fi
