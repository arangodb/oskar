#!/usr/bin/env fish

mkdir -p work/total
mkdir -p work/images

set -l gp work/generate.gnuplot
set -l results work/results.csv
set -l desc work/description.html
set -l src /mnt/buildfiles/performance/Linux/Simple/RAW

if test -z "$DAYS_AGO"
  cat $src/results-*.csv > $results
  set dst /mnt/userfiles/SL/performance/simple/ALL
else
  cat $src/results-*.csv | awk -F, -v start=(date "+%Y%m%d" -d "$DAYS_AGO days ago") '$2 >= start {print $0}' > $results
  set dst /mnt/userfiles/SL/performance/simple/$DAYS_AGO
end

mkdir -p $dst

set -l dates (cat $results | awk -F, '{print $2}' | sort | uniq)

for i in $dates
  set -l secs (date -d $i +%s)

  sed -i "1,\$s:,$i,:,$secs,:" $results
end

echo > $gp
begin
  echo 'set ylabel "seconds"'
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
set -l branches (awk -F, '{print $1}' $results | sort | uniq)

echo "Included tests: $tests"
echo "Included branches: $branches"

echo > $desc

for test in $tests
  echo "Test $test"

  echo "set title \"$test\"" >> $gp
  echo "set output \"work/images/$test.png\"" >> $gp
  echo -n 'plot ' >> $gp
  set -l sep ""

  for branch in $branches
    set -l bname (echo $branch | tr "/" "_")
    set -l btitle (echo $branch | tr "/" " " | tr "_" "-")
    set -l filename work/total/$bname-$test.csv
    set -l c ""

    switch $branch
      case '3.4'
        set c black
      case '3.5'
        set c blue
      case 'devel'
        set c red
    end

    awk -F, "\$1 == \"$branch\" && \$3 == \"$test\" {print \$2 \" \" \$5}" $results | sort > $filename

    if test -s $filename
      if test -n "$c"
        echo -n "$sep\"$filename\" with linespoints linewidth 3 lc rgb '$c' title '$btitle'" >> $gp
      else
        echo -n "$sep\"$filename\" with linespoints linewidth 3 title '$btitle'" >> $gp
      end

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

cp work/images/*.png $dst
