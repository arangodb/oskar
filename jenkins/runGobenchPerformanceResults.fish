#!/usr/bin/env fish

mkdir -p work/total
mkdir -p work/images

set -l gp work/generate.gnuplot
set -l results work/results.csv
set -l desc work/description.html
set -l src /mnt/buildfiles/performance/Linux/Gobench/RAW

if test -z "$DAYS_AGO"
  cat $src/results-*.csv > $results
else
  cat $src/results-*.csv | awk -F, -v start=(date "+%Y%m%d" -d "$DAYS_AGO days ago") '$2 >= start {print $0}' > $results
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
  set -l testname (echo $test | tr " " "_")

  echo "set title \"$test\"" >> $gp
  echo "set output \"work/images/$testname.png\"" >> $gp
  echo -n 'plot ' >> $gp
  set -l sep ""

  for pl in HTTP,1 VST,3
    string split , $pl | begin read p; read l; end;

    for vc in 3.4,black 3.5,blue devel,red
      string split , $vc | begin read v; read c; end;
      set -l vv (echo $v | awk -F. '{ if ($1 == "devel") print "^devel$"; else print "^v?" $1 "\\\\." $2 "(\\\\..*)?$"; }')

      awk -F, "\$1 ~ /$vv/ && \$3 == \"$test\" && \$9 == \"$p\" {print \$2 \" \" \$5}" $results | sort > work/total/$v-$p-$testname.csv

      if test -s work/total/$v-$p-$testname.csv
        echo -n "$sep\"work/total/$v-$p-$testname.csv\" with linespoints linewidth 3 lc rgb '$c' dt $l title '$v $p'" >> $gp
        set sep ", "
      end
    end
  end

  echo >> $gp
  echo >> $gp

  echo "<br/>" >> $desc
  echo "<img src=\"ws/work/images/$testname.png\"></img>" >> $desc
end

if test (count work/images/*.png) -gt 0
  rm -f work/images/*.png
end

echo "Generating images"
"$DOCKER" run -v (pwd)/work:/work pavlov99/gnuplot gnuplot $gp
