#!/usr/bin/env fish

mkdir -p work/total
mkdir -p work/images

set -l gp work/generate.gnuplot
set -l results work/results.csv
set -l desc work/description.html
set -l PERF_TYPE Compiler
set -l PERF_OUT compiler
set -l PERF_COL 4

source jenkins/helper/performance.fish
