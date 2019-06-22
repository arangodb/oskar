#!/usr/bin/env fish

mkdir -p work/total
mkdir -p work/images

set -l gp work/generate.gnuplot
set -l desc work/description.html
set -l d /mnt/buildfiles/performance

echo > $gp
echo > $desc
begin
  echo 'set yrange [0:]'
  echo 'set format x "%12.0f"'
  echo 'set term png size 2048,800'
  echo
end >> $gp

set -l tests (awk -F, '{print $3}' $d/results-*.csv | sort | uniq)

for test in $tests
  echo "Test $test"

  echo "set output \"work/images/$test.png\"" >> $gp
  echo -n 'plot ' >> $gp
  set -l sep ""

  for vc in 3.4,black 3.5,blue devel,red
    string split , $vc | begin read v; read c; end;
    set -l vv (echo $v | awk -F. '{ if ($1 == "devel") print "^devel$"; else print "^v?" $1 "\\\\." $2 "(\\\\..*)?$"; }')
    echo $vv

    awk -F, "\$1 ~ /$vv/ && \$3 == \"$test\" {print \$2 \" \" \$5}" $d/results-*.csv > work/total/$v-$test.csv

    if test -s work/total/$v-$test.csv
      echo -n "$sep\"work/total/$v-$test.csv\" with linespoints linewidth 3 lc rgb '$c' title '$v'" >> $gp
      set sep ", "
    end
  end

  echo >> $gp
  echo >> $gp

  echo "<h1>$test</h1>" >> $desc
  echo "<img src=\"ws/work/images/$test.png\"></img>" >> $desc
end

if test (count work/images/*.png) -gt 0
  rm -f work/images/*.png
end

echo "Generating images"
docker run -v (pwd)/work:/work pavlov99/gnuplot gnuplot $gp
