#!/usr/bin/env fish
ssh -o StrictHostKeyChecking=no -T git@github.com

apt install -y bc

cd /mini-chaos/ ; ./start_ubuntu.sh /$argv[1]/ArangoDB/bin /$argv[1]/output $argv[2]
