#!/bin/bash

install_bash_lib(){
    ## get bash_lib - code works without this lib ## TODO set to fixed versioin
    OBI_VERSION="arango"
    cd "$ARANGO_INSTALL" || exit 1
    wget https://raw.githubusercontent.com/ObiWahn/config/${OBI_VERSION}/etc/skel.obi/.bashrc.d/all/bash_lib || true
    chmod 666 bash_lib
}

## run installations

install_bash_lib

echo "setup done"
