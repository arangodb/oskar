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

case "$1" in

  "--cluster")
    shift
    while ! ((set -o noclobber ; date > $PORTDIR/$port && echo "$PORTDIR/$port" > ./ports &&\
                                 date > $PORTDIR/`expr $port + 1` && echo "$PORTDIR/`expr $port + 1`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 2` && echo "$PORTDIR/`expr $port + 2`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 3` && echo "$PORTDIR/`expr $port + 3`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 10` && echo "$PORTDIR/`expr $port + 10`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 11` && echo "$PORTDIR/`expr $port + 11`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 12` && echo "$PORTDIR/`expr $port + 12`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 13` && echo "$PORTDIR/`expr $port + 13`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 20` && echo "$PORTDIR/`expr $port + 20`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 21` && echo "$PORTDIR/`expr $port + 21`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 22` && echo "$PORTDIR/`expr $port + 22`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 23` && echo "$PORTDIR/`expr $port + 23`" >> ./ports) 2> /dev/null)
    do
      [ -e "./ports" ] && while read -r line; do rm -f "$line"; done < ./ports
      rm -f ./ports
      port=`expr $port + $INCR`
    done

    echo -n "$port `expr $port + 1` `expr $port + 2` `expr $port + 3`\
          `expr $port + 10` `expr $port + 11` `expr $port + 12` `expr $port + 13`\
          `expr $port + 20` `expr $port + 21` `expr $port + 22` `expr $port + 23`"
  ;;

  "--activefailover")
    shift
    while ! ((set -o noclobber ; date > $PORTDIR/$port && echo "$PORTDIR/$port" > ./ports &&\
                                 date > $PORTDIR/`expr $port + 1` && echo "$PORTDIR/`expr $port + 1`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 2` && echo "$PORTDIR/`expr $port + 2`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 10` && echo "$PORTDIR/`expr $port + 10`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 11` && echo "$PORTDIR/`expr $port + 11`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 12` && echo "$PORTDIR/`expr $port + 12`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 20` && echo "$PORTDIR/`expr $port + 20`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 21` && echo "$PORTDIR/`expr $port + 21`" >> ./ports &&\
                                 date > $PORTDIR/`expr $port + 22` && echo "$PORTDIR/`expr $port + 22`" >> ./ports) 2> /dev/null)
    do
      [ -e "./ports" ] && while read -r line; do rm -f "$line"; done < ./ports
      rm -f ./ports
      port=`expr $port + $INCR`
    done

    echo -n "$port `expr $port + 1` `expr $port + 2`\
          `expr $port + 10` `expr $port + 11` `expr $port + 12`\
          `expr $port + 20` `expr $port + 21` `expr $port + 22`"
  ;;

  "--single")
    while ! ((set -o noclobber ; date > $PORTDIR/$port && echo "$PORTDIR/$port" > ./ports &&\
                                 date > $PORTDIR/`expr $port + 1` && echo "$PORTDIR/`expr $port + 1`" >> ./ports) 2> /dev/null)
    do
      [ -e "./ports" ] && while read -r line; do rm -f "$line"; done < ./ports
      rm -f ./ports
      port=`expr $port + $INCR`
    done

    echo -n "$port `expr $port + 1`"
  ;;

  *)
    "Unknown mode as the first parameter! Should be: --single or --activefailover or --cluster."
    exit 1
  ;;
esac

rm -f ./ports
