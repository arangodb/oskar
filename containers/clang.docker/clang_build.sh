#!/bin/bash
set -u

source $ARANGO_INSTALL/bash_lib || { echo "failed to source bash lib"; exit 1; }
ferr() { _o_ferrx "$@"; }
cd "${ARANGO_SOURCE}" || ferr "could not enter source dir"

run_cmake() {
    mkdir -p "${ARANGO_BUILD}"
    cd "${ARANGO_BUILD}" || ferr "could not enter build dir"

    "$@" \
        -DCMAKE_BUILD_TYPE=Debug \
        -DUSE_MAINTAINER_MODE=ON \
        -DUSE_FAILURE_TESTS=ON \
        -DUSE_ENTERPRISE=ON \
        -DUSE_JEMALLOC=OFF \
        "${ARANGO_SOURCE}" || ferr "failed to run cmake"
}

scan_build() {
    run_cmake scan-build-8 cmake
    scan-build-8 -o "${ARANGO_WORK}/clang-scan-build-result" make -j "$(nproc)" || ferr "failed to build"
}

case $1 in
    clang-format)
        ferr "$1 not implemented"
    ;;
    clang-tidy)
        ferr "$1 not implemented"
    ;;
    *)
        echo "running default scan_build"
        scan_build
    ;;
esac
