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

port=9000
INCR=1

find $PORTDIR -type f -cmin +$TIMEOUT -exec rm "{}" ";"

echo -n "" > portfiles
if test "$1" == "--cluster" ; then
  shift
  while ! ((set -o noclobber ; date > $PORTDIR/$port && $(echo -n "$PORTDIR/$port" >> portfiles) &&\
                               date > $PORTDIR/`expr $port + 1` && $(echo -n " $PORTDIR/`expr $port + 1`" >> portfiles) &&\
                               date > $PORTDIR/`expr $port + 2` && $(echo -n " $PORTDIR/`expr $port + 2`" >> portfiles) &&\
                               date > $PORTDIR/`expr $port + 3` && $(echo -n " $PORTDIR/`expr $port + 3`" >> portfiles) &&\
                               date > $PORTDIR/`expr $port + 10` && $(echo -n " $PORTDIR/`expr $port + 10`" >> portfiles) &&\
                               date > $PORTDIR/`expr $port + 11` && $(echo -n " $PORTDIR/`expr $port + 11`" >> portfiles) &&\
                               date > $PORTDIR/`expr $port + 12` && $(echo -n " $PORTDIR/`expr $port + 12`" >> portfiles) &&\
                               date > $PORTDIR/`expr $port + 13` && $(echo -n " $PORTDIR/`expr $port + 13`" >> portfiles) &&\
                               date > $PORTDIR/`expr $port + 20` && $(echo -n " $PORTDIR/`expr $port + 20`" >> portfiles) &&\
                               date > $PORTDIR/`expr $port + 21` && $(echo -n " $PORTDIR/`expr $port + 21`" >> portfiles) &&\
                               date > $PORTDIR/`expr $port + 22` && $(echo -n " $PORTDIR/`expr $port + 22`" >> portfiles) &&\
                               date > $PORTDIR/`expr $port + 23` && $(echo -n " $PORTDIR/`expr $port + 23`" >> portfiles)) 2> /dev/null)
  do
    sleep 0.5
    port=`expr $port + $INCR`
    rm -f $(cat portfiles)
    echo -n "" > portfiles
  done

  echo "`expr $port + 1` `expr $port + 11` `expr $port + 21`" > ports

  echo "$port `expr $port + 1` `expr $port + 2` `expr $port + 3`\
        `expr $port + 10` `expr $port + 11` `expr $port + 12` `expr $port + 13`\
        `expr $port + 20` `expr $port + 21` `expr $port + 22` `expr $port + 23`"
else
  while ! ((set -o noclobber ; date > $PORTDIR/$port && $(echo -n "$PORTDIR/$port") >> portfiles &&\
                               date > $PORTDIR/`expr $port + 1` && $(echo -n " $PORTDIR/`expr $port + 1`") >> portfiles) 2> /dev/null)
  do
    sleep 0.5
    port=`expr $port + $INCR`
    rm -f $(cat portfiles)
    echo -n "" > portfiles
  done

  echo "`expr $port + 1`" > ports
  
  echo "$port `expr $port + 1`"
fi
