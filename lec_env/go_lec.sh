#!/bin/bash -f
cd /home/share_file/cadence
source add_path
source add_license
cd -
lec -64 -dofile ./lec.tcl &
