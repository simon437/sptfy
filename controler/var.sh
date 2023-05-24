#!/bin/bash
# @Author Simon Olfs
# @Date 24.05.2023

# Initial option values
opt_h=0                             # -h help
opt_v=0                             # -v version
opt_d=0                             # -d devices
opt_d_val=''                        # (default) value for -d argument
opt_p=0                             # -p playlist
opt_p_val='Release Radar'           # (default) value for -p argument
opt_n=0                             # -n next

# Some global variables
set -o nounset                      # bash: abort on undefined variables
VERSION="0.1"                       # current version of the script
PROGNAME=${0##*/}                   # same as PROGNAME=$(basename "$0")
root="/home/simon/prog/sptfy"       # root for of the programm
config="$root/sptfy.conf"           # configuration file

# Exit Codes
EXIT_OK=0
EXIT_USAGE=64                       # analogously to EX_USAGE in /usr/include/sysexits.h
EXIT_INTERNAL_ERROR=70              # EX_INTERNAL_ERROR in sysexits.h
EXIT_GENERAL_ERROR=80               # nothing similar in sysexits.h

