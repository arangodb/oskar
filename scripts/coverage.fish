#!/usr/bin/env fish
set -l c 0

cd $INNERWORKDIR
python3 "$WORKSPACE/jenkins/helper/aggregate_coverage.py" $INNERWORKDIR/ gcov coverage 


