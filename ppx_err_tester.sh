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
RC="\033[0m"    # Reset Color

# Variables
RM="rm -rf"
NAME=pipex
in1=infile
out1=outfile1
out2=outfile2
bin1=ppx_tmp
dir1=dir_tmp
log1=pipex_error.log

# Globals
old_PATH=$PATH
TESTS_PASSED=0
TESTS_FAILED=0

# Commands
DIFF_CMD=$(which diff)
GREP_CMD=$(which grep)
TAIL_CMD=$(which tail)
SLEEP_CMD=$(which sleep)
TR_CMD=$(which tr)
WC_CMD=$(which wc)
PS_CMD=$(which ps)
VALGRIND_CMD=$(which valgrind)
VALGRIND_FLAGS="--leak-check=full --show-leak-kinds=all --track-fds=yes --trace-children=yes"
VALGRIND_FULL=""
TIMEOUT_CMD=$(which timeout)
TIMEOUT_FULL=""

# Valgrind command
if [ -n "$VALGRIND_CMD" ]; then
  VALGRIND_FULL="$VALGRIND_CMD $VALGRIND_FLAGS"
fi

# Timeout command
if [ -n "$TIMEOUT_CMD" ]; then
  TIMEOUT_FULL="$TIMEOUT_CMD 2"
fi

check_requirements() {
  if [[ -z "$TIMEOUT_FULL" ]]; then
    printf "${YB}WARNING:${RC} ${C}'timeout'${RC} not available.\n"
  fi
  if [[ -z "$VALGRIND_FULL" ]]; then
    printf "${YB}WARNING:${RC} ${C}'valgrind'${RC} not available.\n"
  fi
}

cleanup() {
  export PATH="$old_PATH"
  ${RM} ${in1} ${out1} ${out2} ${bin1} ${dir1}
}

handle_ctrlc() {
  printf "\n${RB}Test interrupted by user.${RC}\n"
  cleanup
  exit 1
}

setup_test_files() {
  touch ${in1}         # Universal infile
  touch ${out1}        # Pipex outfile
  touch ${out2}        # Shell outfile
  cp ${NAME} ${bin1}   # Executable permission
  mkdir -p "./${dir1}" # Directory as command
  echo -n >"${log1}"   # create log file
}

print_title_line() {
  local title="$1"
  local title_width=60
  local msg_len=${#title}
  local pad_len=$(((title_width - msg_len) / 2))

  title_pad="$(printf '%*s' "$pad_len" '' | $TR_CMD ' ' '=')"
  printf "\n${P}%s${RC}${GB} %s ${P}%s${RC}\n\n" \
    "$title_pad" "$title" "$title_pad"
}

print_header() {
  local header="$1"
  local header_width=61
  local msg_len=${#header}
  local pad_len=$(((header_width - msg_len) / 2 - 1))
  line="$(printf '%*s' "$header_width" '' | $TR_CMD ' ' '=')"

  printf "\n${P}%s${RC}\n" "$line"
  printf "${P}|%*s${GB}%s${RC}%*s${P}|${RC}\n" \
    "$pad_len" "" "$header" "$pad_len" ""
  printf "${P}%s${RC}\n\n" "$line"
}

print_summary() {
  print_header "SYMMARY"
  printf "${BB}Tests passed:${RC} ${GB}$TESTS_PASSED${RC}\n"
  printf "${BB}Tests failed:${RC} ${RB}$TESTS_FAILED${RC}\n\n"

  if [ $TESTS_FAILED -eq 0 ]; then
    printf "${GB}All tests passed!${RC}\n"
  else
    printf "${RB}See ${log1} for details.${RC}\n"
  fi
}

test_concurrency() {
  local start_time=0
  local end_time=0
  local elapsed_time=1

  if [ -n "$TIMEOUT_FULL" ]; then
    start_time=$(date +%s.%N)
    $TIMEOUT_FULL ./pipex "/dev/random" "cat" "head -n 1" "${out1}" >/dev/null
    end_time=$(date +%s.%N)
  else
    printf "${BB}Concurrency:${RC} ${YB}'timeout' not available${RC}\n"
    return
  fi

  elapsed_time=$(echo "$end_time - $start_time" | bc)
  if (($(echo "$elapsed_time < 1" | bc -l))); then
    printf "${BB}Concurrency:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${BB}Concurrency:${RC} ${RB}KO${RC}\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_zombie_processes() {
  local zombie_count=0

  if [ -n "$TIMEOUT_FULL" ]; then
    $TIMEOUT_FULL ./pipex "${in1}" "sleep 1" "echo test" "${out1}" 2>/dev/null
  else
    ./pipex "${in1}" "sleep 1" "echo test" "${out1}" 2>/dev/null
  fi

  $SLEEP_CMD 0.5

  zombie_count=$($PS_CMD aux | $GREP_CMD -v grep |
    $GREP_CMD "pipex" | $GREP_CMD -w 'Z' | $WC_CMD -l)

  if [ "$zombie_count" -gt 0 ]; then
    printf "${BB}Zombies:${RC} ${RB}KO${RC}\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    printf "${BB}Zombies:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

test_signal_handler() {
  if [ -n "$TIMEOUT_FULL" ]; then
    $TIMEOUT_FULL ./pipex "${in1}" "echo" "sleep 2" "${out1}" >/dev/null &
  else
    ./pipex "${in1}" "echo" "sleep 2" "${out1}" >/dev/null &
  fi

  pid=$!
  sleep 0.5

  kill -SIGINT "$pid"
  wait "$pid"
  sigint_exit=$?

  if command -v gcc >/dev/null 2>&1; then
    cat >test_segfault.c <<EOF # Create small segfault program
#include <stdio.h>
int main() {
    char *ptr = NULL;
    *ptr = 'x';
    return 0;
}
EOF
    gcc -o test_segfault test_segfault.c 2>/dev/null
    if [ -n "$TIMEOUT_FULL" ]; then
      $TIMEOUT_FULL ./pipex "${in1}" "ls" "./test_segfault" "${out1}" 2>/dev/null
    else
      ./pipex "${in1}" "ls" "./test_segfault" "${out1}" 2>/dev/null
    fi
  else
    printf "${BB}Signals:${RC} ${YB}'gcc' not available${RC}\n"
  fi
  sigsegv_exit=$?

  if [ "$sigint_exit" -eq 130 ] && [ "$sigsegv_exit" -eq 139 ]; then
    printf "${BB}Signals:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${BB}Signals:${RC} ${RB}KO${RC}\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  ${RM} test_segfault.c test_segfault
}

check_leaks() {
  local infile="$1"
  local cmd1="$2"
  local cmd2="$3"
  local outfile="$4"
  local has_leaks=0
  local open_fds=0

  leak_output=$($VALGRIND_FULL --log-file=/dev/stdout \
    ./pipex "$infile" "$cmd1" "$cmd2" "$outfile" 2>/dev/null)

  open_fds=$(echo "$leak_output" | $GREP_CMD -A 1 "FILE DESCRIPTORS" |
    $TAIL_CMD -n 1 | $GREP_CMD -o '[0-9]\+ open' | $GREP_CMD -o '[0-9]\+')

  if echo "$leak_output" | $GREP_CMD -q "definitely lost: [^0]" ||
    echo "$leak_output" | $GREP_CMD -q "indirectly lost: [^0]" ||
    { [ -n "$open_fds" ] && [ "$open_fds" -gt 4 ]; }; then
    has_leaks=1
  fi

  echo "$leak_output"
  return $has_leaks
}

compare_results() {
  # set local variables for readibility
  local infile="$1"
  local cmd=""
  local cmd1="$2"
  local cmd2="$3"
  local empty_cmds=0
  local outfile1="$4"
  local outfile2="$5"
  local title="$6"

  # check if testing empty commands
  if [ -z "$(echo "$cmd1" | $TR_CMD -d '[:space:]')" ] ||
    [ -z "$(echo "$cmd2" | $TR_CMD -d '[:space:]')" ]; then
    empty_cmds=1
  fi

  # Run pipex with timeout if available
  cmd="$TIMEOUT_FULL ./$NAME"
  pipex_output=$($cmd "$infile" "$cmd1" "$cmd2" "$outfile1" 2>&1)
  pipex_exit=$?

  # Update pipex output in case of segfault
  if [ "$pipex_exit" -eq 139 ]; then
    pipex_output="${Y}Segmentation fault (SIGSEGV) (core dumped)${RC}\n"
  fi

  # Run shell with timeout if available
  cmd="$TIMEOUT_FULL bash -c"
  if [ "$empty_cmds" -eq 1 ]; then
    shell_output=$($cmd "< $infile \"$cmd1\" | \"$cmd2\" > $outfile2" 2>&1)
  else
    shell_output=$($cmd "< $infile $cmd1 | $cmd2 > $outfile2" 2>&1)
  fi
  shell_exit=$?

  # Check for output diffs
  if [ -n "$DIFF_CMD" ]; then
    diff_output=$($DIFF_CMD "$outfile1" "$outfile2")
  else
    diff_output="not available"
  fi

  # Check for memory leaks
  leak_output=$(check_leaks "$infile" "$cmd1" "$cmd2" "$outfile1")
  leak_result=$?

  # Print test title
  print_title_line "$title"

  # Print used commands
  printf "${GB}Pipex:${RC} ./pipex $infile \"$cmd1\" \"$cmd2\" $outfile1\n"
  if [ "$empty_cmds" -eq 1 ]; then
    printf "${GB}Shell:${RC} < $infile \"$cmd1\" | \"$cmd2\" > $outfile2\n\n"
  else
    printf "${GB}Shell:${RC} < $infile $cmd1 | $cmd2 > $outfile2\n\n"
  fi

  # print both outputs
  [ -n "$pipex_output" ] && printf "${GB}Pipex:${RC} $pipex_output${RC}\n"
  [ -n "$shell_output" ] && printf "${GB}Shell:${RC} $shell_output${RC}\n\n"

  # Print exit codes
  if [ "$pipex_exit" -eq "$shell_exit" ]; then
    printf "${BB}Exit code:${RC} ${GB}OK${RC}\n"
  else
    printf "${BB}Exit code:${RC} ${RB}KO${RC}\n"
  fi

  # Print diffs
  if [ -z "$DIFF_CMD" ]; then
    printf "${BB}Diff:${RC} ${YB}not available${RC}\n"
  elif [ -z "$diff_output" ] || [ ! -w "$outfile1" ]; then
    printf "${BB}Diff:${RC} ${GB}OK${RC}\n"
  else
    printf "${BB}Diff:${RC} ${RB}KO${RC}\n"
  fi

  # Print leaks
  if [ -z "$VALGRIND_CMD" ]; then
    printf "${BB}Leaks:${RC} ${YB}not available${RC}\n"
  elif [ "$leak_result" -ne 1 ]; then
    printf "${BB}Leaks:${RC} ${GB}OK${RC}\n"
  else
    printf "${BB}Leaks:${RC} ${RB}KO${RC}\n"
  fi

  # Update error log
  if [ "$pipex_exit" -ne "$shell_exit" ] || [ "$leak_result" -eq 1 ] ||
    { [ -n "$diff_output" ] && [ -w "$outfile1" ] &&
      [ "$diff_output" != "not available" ]; }; then
    echo "Test failed: $title" >>"${log1}"
    echo "Pipex exit: $pipex_exit" >>"${log1}"
    echo "Shell exit: $shell_exit" >>"${log1}"
    echo "Pipex output: $pipex_output" >>"${log1}"
    echo "Shell output: $shell_output" >>"${log1}"
    if [ -n "$diff_output" ] && [ -w "$outfile1" ] &&
      [ "$diff_output" != "not available" ]; then
      echo "Diff result: Diffs detected" >>"${log1}"
      echo "$diff_output" >>"${log1}"
    else
      echo "Diff result: OK" >>"${log1}"
    fi
    if [ $leak_result -eq 1 ]; then
      echo "Leaks result: Leaks detected" >>"${log1}"
      echo "$leak_output" >>"${log1}"
    else
      echo "Leaks result: OK" >>"${log1}"
    fi
    echo "=====================================================" >>"${log1}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

run_error_tests() {
  print_header "ERROR TESTS"
  compare_results "noinfile" "ls" "wc" "${out1}" "${out2}" "INFILE DOES NOT EXIST"
  compare_results "noinfile" "xxx" "wc" "${out1}" "${out2}" "INFILE DOES NOT EXIST, INVALID CMD1"

  chmod -r ${in1}
  compare_results "${in1}" "ls" "wc" "${out1}" "${out2}" "INFILE NO READ PERMISSION, VALID CMDS"
  chmod +r ${in1}

  chmod -w ${out1}
  chmod -w ${out2}
  compare_results "${in1}" "ls" "wc" "${out1}" "${out2}" "OUTFILE NO WRITE PERMISSION, VALID CMDS"
  chmod +w ${out1}
  chmod +w ${out2}

  chmod -x ${bin1}
  compare_results "${in1}" "./${bin1}" "wc" "${out1}" "${out2}" "NO EXEC PERMISSION CMD1"
  compare_results "${in1}" "wc" "./${bin1}" "${out1}" "${out2}" "NO EXEC PERMISSION CMD2"
  chmod +x ${bin1}

  compare_results "${in1}" "./${dir1}/" "ls" "${out1}" "${out2}" "CMD1 IS FOLDER, VALID CMD2"
  compare_results "${in1}" "ls" "./${dir1}/" "${out1}" "${out2}" "VALID CMD1, CMD2 IS FOLDER"

  compare_results "${in1}" "xxx" "wc" "${out1}" "${out2}" "INVALID CMD1, VALID CMD2"
  compare_results "${in1}" "/xxx/xxx" "wc" "${out1}" "${out2}" "INVALID CMD1 (ABS), VALID CMD2"
  compare_results "${in1}" "ls" "xxx" "${out1}" "${out2}" "VALID CMD1, INVALID CMD2"
  compare_results "${in1}" "ls" "/xxx/xxx" "${out1}" "${out2}" "VALID CMD1, INVALID CMD2 (ABS)"
  compare_results "${in1}" "xxx" "/xxx/xxx" "${out1}" "${out2}" "INVALID CMD1, INVALID CMD2 (ABS)"

  compare_results "${in1}" "" "wc" "${out1}" "${out2}" "NULL STRING CMD1, VALID CMD2"
  compare_results "${in1}" "ls" "     " "${out1}" "${out2}" "VALID CMD1, EMPTY CMD2"
  compare_results "${in1}" "" "     " "${out1}" "${out2}" "NULL STRING CMD1, EMPTY CMD2"

  compare_results "${in1}" "ls -?" "grep c" "${out1}" "${out2}" "BAD ARGS CMD1, VALID CMD2"
  compare_results "${in1}" "ls -?" "wc -9001" "${out1}" "${out2}" "BAD ARGS CMD1, BAD ARGS CMD2"

  unset PATH
  compare_results "${in1}" "ls" "wc" "${out1}" "${out2}" "PATH ENVP DOES NOT EXIST, INVALID CMDS"
  compare_results "${in1}" "/bin/ls" "wc" "${out1}" "${out2}" "NO PATH ENVP, VALID CMD1 (ABS), INVALID CMD2"
  compare_results "${in1}" "/bin/ls" "/bin/cat" "${out1}" "${out2}" "NO PATH ENVP, VALID CMD1 (ABS), VALID CMD2 (ABS)"
  export PATH="$old_PATH"
}

run_valid_tests() {
  local infile="Makefile"
  print_header "VALID TESTS"
  compare_results $infile "cat" "wc -l" "${out1}" "${out2}" "CAT CMD1, WC CMD2"
  compare_results $infile "grep a" "wc -w" "${out1}" "${out2}" "GREP CMD1, WC CMD2"
  compare_results $infile "head -n 5" "tail -n 2" "${out1}" "${out2}" "HEAD CMD1, TAIL CMD2"
  compare_results $infile "sort" "uniq" "${out1}" "${out2}" "SORT CMD1, UNIQ CMD2"
  compare_results $infile "tr a-z A-Z" "tee ${out2}" "${out1}" "${out2}" "TR CMD1, TEE CMD2"
  compare_results $infile "echo -n hello" "wc -c" "${out1}" "${out2}" "ECHO CMD1, WC CMD2"
  compare_results $infile "/bin/ls" "/bin/cat" "${out1}" "${out2}" "LS CMD1 (PATH), CAT CMD2 (PATH)"
}

run_extra_tests() {
  print_header "EXTRA TESTS"
  test_concurrency
  test_signal_handler
  test_zombie_processes
}

trap handle_ctrlc SIGINT

if ! [ -f "$NAME" ]; then
  printf "\n${CB}INFO: ${RC} binary ${Y}<$NAME>${RC} not found, running ${P}make${RC}...\n"
  make >/dev/null
fi

if [ -f "$NAME" ]; then
  check_requirements
  setup_test_files
  run_error_tests
  run_valid_tests
  run_extra_tests
  print_summary
  cleanup
else
  printf "${RB}ERROR: ${RC}${Y}binary <$NAME> not found${RC}\n"
  exit 1
fi
