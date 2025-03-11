set -l gp work/generate-$OS.gnuplot
set -l results work/results-$OS.csv
set -l desc work/description-$OS.html
set -l src /mnt/buildfiles/performance/$OS/$PERF_TYPE/RAW
set -l images work/images/$OS
set -l total work/total/$OS

mkdir -p $images
mkdir -p $total

if count $src/results-*.csv > /dev/null
  set -l csvfiles (ls -1 $src/results-*.csv \
    | sort -r \
    | awk -F/ '{key = substr($NF,9,length($NF)-16); if (a[key] != 1) print $0; a[key] = 1 }' | sort)

  if test -z "$DAYS_AGO"
    awk -F, -v OFS=, '{$2 = substr($2,1,8); print $0;}' $csvfiles > $results
    set dst /mnt/userfiles/SL/performance/$PERF_OUT/ALL
  else
    cat $csvfiles | awk -F, -v OFS=, -v start=(date "+%Y%m%d" -d "$DAYS_AGO days ago") 'substr($2,1,8) >= start {$2 = substr($2,1,8); print $0}' > $results
    set dst /mnt/userfiles/SL/performance/$PERF_OUT/$DAYS_AGO
  end

  mkdir -p $dst

  set -l dates (cat $results | awk -F, '{print $2}' | sort | uniq)

  for i in $dates
    set -l secs (date -d $i +%s)

    sed -i "1,\$s:,$i,:,$secs,:" $results
  end

  set -l tests (awk -F, '{print $3}' $results | sort | uniq)
  set -l branches (awk -F, '{print $1}' $results | sort | uniq)

  echo "Included tests: $tests"
  echo "Included branches: $branches"

  set -l lookup work/branches_lookup.txt

  echo > $gp
  begin
    echo 'set ylabel "seconds"'
    echo 'set yrange [0:]'
    echo 'set term png size 2048,800'
    echo 'set key left bottom'
    echo 'set xtics nomirror rotate by 90 right font ",8"'

    echo -n 'set xtics ('
    set -l sep ""

    if test -n "DAYS_AGO" -a "$DAYS_AGO" -eq 0
      rm -f $lookup
      touch $lookup
      set -l c 0

      for i in $branches
	echo $i >> $lookup
	echo -n $sep\"$i\" $c
	set sep ", "
	set c (expr $c + 1)
      end

      echo ')'
      echo "set xrange [-1:$c]"
      echo "set grid xtics ytics lw 2 lt 2 dt 3"
    else
      for i in $dates
	set -l secs (date -d $i +%s)
	set -l iso (date -I -d $i)

	echo -n $sep\"$iso\" $secs
	set sep ", "
      end

      echo ')'
    end
  end >> $gp

  echo "<h1 id=\"$OS\">$OS</h1>" > $desc

  set -l filenames

  for test in $tests
    echo "<a href=\"#$OS-$test\"/>$test</a> "
  end >> $desc

  for test in $tests
    echo "Test $test"

    echo "set title \"$test\"" >> $gp
    echo "set output \"$images/$test.png\"" >> $gp
    echo -n 'plot ' >> $gp
    set -l sep ""

    for branch in $branches
      set -l bname (echo $branch | tr "/" "_")
      set -l btitle (echo $branch | tr "/" " " | tr "_" "-")
      set -l filename $total/$bname-$test.csv
      set filenames $filenames $filename
      set -l c ""

      switch $branch
	case '3.4'
	  set c black
	case '3.5'
	  set c blue
	case 'devel'
	  set c red
      end

      if test -n "$DAYS_AGO" -a "$DAYS_AGO" -eq 0
	set -l pos (expr (fgrep -n "$branch" $lookup | head -1 | awk -F: '{print $1}') - 1)
	awk -F, "\$1 == \"$branch\" && \$3 == \"$test\" {print $pos \" \" \$$PERF_COL}" $results | sort > $filename
      else
	awk -F, "\$1 == \"$branch\" && \$3 == \"$test\" {print \$2 \" \" \$$PERF_COL}" $results | sort > $filename
      end

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
    echo "<a name=\"$OS-$test\"/>" >> $desc
    echo "<img src=\"ws/$images/$test.png\" style=\"width:100%\"/>" >> $desc
  end

  if count $images/*.png > /dev/null
    rm -f $images/*.png
  end

  echo "Generating images"
  "$DOCKER" run -v (pwd)/work:/work pavlov99/gnuplot gnuplot $gp
  or begin
    echo "=== $gp ==="
    cat $gp
    echo

    for i in $filenames
      echo "=== $i ==="
      cat $i
      echo
    end
    exit 1
  end

  if count $images/*.png > /dev/null
    cp $images/*.png $dst
  end
end
