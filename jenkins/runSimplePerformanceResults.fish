#!/usr/bin/env fish

mkdir -p work/total
mkdir -p work/images

set -l gp work/generate.gnuplot
set -l d /mnt/buildfiles/performance

echo > $gp
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

  for v in 3.4 3.5 devel
    awk -F, "\$1 == \"$v\" && \$3 == \"$test\" {print \$2 \" \" \$5}" $d/results-*.csv > work/total/$v-$test.csv

    if test -s work/total/$v-$test.csv
      echo -n "$sep\"work/total/$v-$test.csv\" with linespoints linewidth 3 title '$v'" >> $gp
      set sep ", "
    end
  end

  echo >> $gp
  echo >> $gp
end

if test (count work/images/*.png) -gt 0
  rm -f work/images/*.png
end

echo "Generating images"
docker run -v (pwd)/work:/work pavlov99/gnuplot gnuplot $gp
