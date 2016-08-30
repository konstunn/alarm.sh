#!/bin/bash
mkdir -p ~/bin
cd ~/bin

# TODO check if it already exists, check if it is valid
# TODO add a symlink to system-wide PATH
ln -s $OLDPWD/alarm.sh alarm.sh
