#!/usr/bin/env fish

mkdir -p work/total
mkdir -p work/images

set -l gp work/generate.gnuplot
set -l results work/results.csv
set -l desc work/description.html
set -l d /mnt/buildfiles/performance

if test -z "$DAYS_AGO"
  cat /mnt/buildfiles/performance/results-*.csv > $results
else
  cat /mnt/buildfiles/performance/results-*.csv | awk -F, -v start=(date "+%Y%m%d" -d "$DAYS_AGO days ago") '$2 >= start {print $0}' > $results
end

set -l dates (cat $results | awk -F, '{print $2}' | sort | uniq)

for i in $dates
  set -l secs (date -d $i +%s)

  sed -i "1,\$s:,$i,:,$secs,:" $results
end

echo > $gp
begin
  echo 'set yrange [0:]'
  echo 'set term png size 2048,800'
  echo 'set key left bottom'
  echo 'set xtics nomirror rotate by 90 right font ",8"'
  echo -n 'set xtics ('
  set -l sep ""
  for i in $dates
    set -l secs (date -d $i +%s)
    set -l iso (date -I -d $i)

    echo -n $sep\"$iso\" $secs
    set sep ", "
  end
  echo ')'
end >> $gp

set -l tests (awk -F, '{print $3}' $results | sort | uniq)

echo > $desc

for test in $tests
  echo "Test $test"

  echo "set title \"$test\"" >> $gp
  echo "set output \"work/images/$test.png\"" >> $gp
  echo -n 'plot ' >> $gp
  set -l sep ""

  for vc in 3.4,grey 3.5,blue devel,red
    string split , $vc | begin read v; read c; end;
    set -l vv (echo $v | awk -F. '{ if ($1 == "devel") print "^devel$"; else print "^v?" $1 "\\\\." $2 "(\\\\..*)?$"; }')

    awk -F, "\$1 ~ /$vv/ && \$3 == \"$test\" {print \$2 \" \" \$5}" $results | sort > work/total/$v-$test.csv

    if test -s work/total/$v-$test.csv
      echo -n "$sep\"work/total/$v-$test.csv\" with linespoints linewidth 3 lc rgb '$c' title '$v'" >> $gp
      set sep ", "
    end
  end

  echo >> $gp
  echo >> $gp

  echo "<br/>" >> $desc
  echo "<img src=\"ws/work/images/$test.png\"></img>" >> $desc
end

if test (count work/images/*.png) -gt 0
  rm -f work/images/*.png
end

echo "Generating images"
docker run -v (pwd)/work:/work pavlov99/gnuplot gnuplot $gp
