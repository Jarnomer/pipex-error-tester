#!/bin/bash

R="\033[0;31m" # Red
G="\033[0;32m" # Green
Y="\033[0;33m" # Yellow
B="\033[0;34m" # Blue
P="\033[0;35m" # Purple
C="\033[0;36m" # Cyan

RB="\033[1;31m" # Bold Red
GB="\033[1;32m" # Bold Green
YB="\033[1;33m" # Bold Yellow
BB="\033[1;34m" # Bold Blue
PB="\033[1;35m" # Bold Purple
CB="\033[1;36m" # Bold Cyan

RC="\033[0m" # Reset

TEST_BREAK="==================================================================="
LOG_BREAK="====================================="

NAME=pipex
OLD_PATH=$PATH
TESTS_PASSED=0
TESTS_FAILED=0
TEST_CURRENT=1
SELECTED_TESTS=""
ALL_TESTS=1

in1=infile
out1=outfile1
out2=outfile2
bin1=ppx_tmp
dir1=dir_tmp
log1=pipex_error.log

DIFF_CMD=$(which diff)
GREP_CMD=$(which grep)
TAIL_CMD=$(which tail)
SED_CMD=$(which sed)
CAT_CMD=$(which cat)
LS_CMD=$(which ls)
TR_CMD=$(which tr)
RM_CMD="rm -rf"

VALGRIND_FULL=""
VALGRIND_CMD=$(which valgrind)
VALGRIND_FLAGS="--leak-check=full \
  --show-leak-kinds=all \
  --track-fds=yes \
  --trace-children=yes"
if [ -n "$VALGRIND_CMD" ]; then
  VALGRIND_FULL="$VALGRIND_CMD $VALGRIND_FLAGS"
fi

TIMEOUT_FULL=""
TIMEOUT_CMD=$(which timeout)
if [ -n "$TIMEOUT_CMD" ]; then
  TIMEOUT_FULL="$TIMEOUT_CMD 2"
fi
