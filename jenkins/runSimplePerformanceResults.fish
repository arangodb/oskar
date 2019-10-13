#!/usr/bin/env fish

set -l PERF_TYPE Simple
set -l PERF_OUT simple
set -l PERF_COL 5

set -l OS Linux
source jenkins/helper/runAnyPerformanceResults.fish
