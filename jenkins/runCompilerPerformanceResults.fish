#!/usr/bin/env fish

set -l PERF_TYPE Compiler
set -l PERF_OUT compiler
set -l PERF_COL 4

set -l OS Linux
source jenkins/helper/runAnyPerformanceResults.fish

set -l OS MAC
source jenkins/helper/runAnyPerformanceResults.fish

begin
  echo '<a href="#Linux"/>Linux</a>'
  echo '<a href="#MAC"/>MAC</a>'
  echo '<hr/>'
  cat work/description-Linux.html
  echo '<hr/>'
  cat work/description-MAC.html
end > work/description.html
