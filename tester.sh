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

# Log separators
TEST_BREAK="==================================================================="
LOG_BREAK="====================================="

# Globals
RM="rm -rf"
NAME=pipex
OLD_PATH=$PATH
TESTS_PASSED=0
TESTS_FAILED=0
TEST_CURRENT=1

# Test files
in1=infile
out1=outfile1
out2=outfile2
bin1=ppx_tmp
dir1=dir_tmp
log1=pipex_error.log

# Commands
DIFF_CMD=$(which diff)
GREP_CMD=$(which grep)
SED_CMD=$(which sed)
CAT_CMD=$(which cat)
TAIL_CMD=$(which tail)
DATE_CMD=$(which date)
SLEEP_CMD=$(which sleep)
LS_CMD=$(which ls)
TR_CMD=$(which tr)
BC_CMD=$(which bc)
WC_CMD=$(which wc)
PS_CMD=$(which ps)
TIMEOUT_CMD=$(which timeout)
TIMEOUT_FULL=""
VALGRIND_CMD=$(which valgrind)
VALGRIND_FLAGS="--leak-check=full --show-leak-kinds=all \
  --track-fds=yes --trace-children=yes"
VALGRIND_FULL=""

# Valgrind command
if [ -n "$VALGRIND_CMD" ]; then
  VALGRIND_FULL="$VALGRIND_CMD $VALGRIND_FLAGS"
fi

# Timeout command
if [ -n "$TIMEOUT_CMD" ]; then
  TIMEOUT_FULL="$TIMEOUT_CMD 2"
fi

# **************************************************************************** #
#    UTILITIES
# **************************************************************************** #

check_requirements() {
  if [ -z "$TIMEOUT_FULL" ]; then
    printf "${YB}WARNING:${RC} ${C}'timeout'${RC} not available.\n"
  fi
  if [ -z "$VALGRIND_FULL" ]; then
    printf "${YB}WARNING:${RC} ${C}'valgrind'${RC} not available.\n"
  fi
}

cleanup() {
  export PATH="$OLD_PATH"
  ${RM} ${in1} ${out1} ${out2} ${bin1} ${dir1}
}

handle_ctrlc() {
  printf "\n${RB}Test interrupted by user.${RC}\n\n"
  cleanup
  exit 1
}

setup_test_files() {
  touch ${in1}         # Universal infile
  touch ${out1}        # Pipex outfile
  touch ${out2}        # Shell outfile
  cp ${NAME} ${bin1}   # Test binary
  mkdir -p "./${dir1}" # Test directory
  echo -n >"${log1}"   # Log file
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

# **************************************************************************** #
#    PRINTING AND LOGGING
# **************************************************************************** #

print_title_line() {
  local title="$1"
  local title_width=60
  local msg_len=${#title}
  local pad_len=$(((title_width - msg_len) / 2))

  title_pad="$(printf '%*s' "$pad_len" '' | $TR_CMD ' ' '=')"
  printf "\n${P}%s${RC} ${GB}TEST ${RC}${PB}${TEST_CURRENT}${RC}" "$title_pad"
  printf " - ${GB}%s ${P}%s${RC}\n\n" "$title" "$title_pad"
}

print_header() {
  local header="$1"
  local header_width=70
  local msg_len=${#header}
  local pad_len=$(((header_width - msg_len) / 2 - 1))
  line="$(printf '%*s' "$header_width" '' | $TR_CMD ' ' '=')"

  printf "\n${P}%s${RC}\n" "$line"
  printf "${P}|%*s${GB}%s${RC}%*s${P} |${RC}\n" \
    "$pad_len" "" "$header" "$pad_len" ""
  printf "${P}%s${RC}\n\n" "$line"
}

print_summary() {
  print_header "SYMMARY"
  printf "${BB}Tests passed:${RC} ${GB}$TESTS_PASSED${RC}\n"
  printf "${BB}Tests failed:${RC} ${RB}$TESTS_FAILED${RC}\n\n"

  if [ $TESTS_FAILED -eq 0 ]; then
    printf "${GB}All tests passed!${RC}\n\n"
  else
    printf "${RB}See ${log1} for details.${RC}\n\n"
  fi
}

update_error_log() {
  local title="$1"

  echo "TEST ${TEST_CURRENT}: $title" >>"${log1}"
  echo "$TEST_BREAK" >>"${log1}"

  if [ "$pipex_exit" -ne "$shell_exit" ]; then
    echo "Exit Code: KO - pipex: $pipex_exit | bash: $shell_exit" >>"${log1}"
  else
    echo "Exit Code: OK" >>"${log1}"
  fi

  if [ "$output_result" -eq 1 ]; then
    echo "Output: KO - Different outputs" >>"${log1}"
    echo "Pipex: $pipex_output" >>"${log1}"
    echo "Shell: $shell_output" >>"${log1}"
  else
    echo "Output: OK" >>"${log1}"
  fi

  if [ -n "$diff_output" ] && [ -w "$outfile1" ]; then
    echo "Diff: KO - Detected" >>"${log1}"
    echo "$LOG_BREAK" >>"${log1}"
    echo "$diff_output" >>"${log1}"
    echo "$LOG_BREAK" >>"${log1}"
  else
    echo "Diff: OK" >>"${log1}"
  fi

  if [ "$leak_result" -eq 1 ]; then
    echo "Leaks: KO - Detected" >>"${log1}"
    echo "$LOG_BREAK" >>"${log1}"
    echo "$leak_output" >>"${log1}"
    echo "$LOG_BREAK" >>"${log1}"
  else
    echo "Leaks: OK" >>"${log1}"
  fi

  echo "$TEST_BREAK" >>"${log1}"
  echo >>"${log1}"
}

print_test_result() {
  print_title_line "$title"

  # Trim "line 1: " from bash output which comes from shell script
  shell_output=$(echo "$shell_output" | $SED_CMD 's/line 1: //g')

  printf "${CB}Pipex:${RC} ./pipex $infile \"$cmd1\" \"$cmd2\" $outfile1\n"
  if [ "$empty_cmds" -eq 1 ]; then
    printf "${GB}Shell:${RC} < $infile \"$cmd1\" | \"$cmd2\" > $outfile2\n\n"
  else
    printf "${GB}Shell:${RC} < $infile $cmd1 | $cmd2 > $outfile2\n\n"
  fi

  if [ -n "$pipex_output" ]; then
    printf "${CB}Pipex:${RC} $pipex_output${RC}"
    printf "${GB}Shell:${RC} $shell_output${RC}\n\n"
    printf "${GB}Exits:${RC} ${CB}pipex:${RC} $pipex_exit "
    printf "${BB}|${RC} ${GB}shell:${RC} $shell_exit${RC}\n\n"
  fi

  if [ "$output_result" -ne 1 ]; then
    printf "${BB}Message:${RC} ${GB}OK${RC}\n"
  else
    printf "${YB}Message:${RC} ${RB}KO${RC}\n"
  fi

  if [ "$pipex_exit" -eq "$shell_exit" ]; then
    printf "${BB}Exit code:${RC} ${GB}OK${RC}\n"
  else
    printf "${YB}Exit code:${RC} ${RB}KO${RC}\n"
  fi

  if [ -z "$diff_output" ] || [ ! -w "$outfile1" ]; then
    printf "${BB}Diff:${RC} ${GB}OK${RC}\n"
  else
    printf "${YB}Diff:${RC} ${RB}KO${RC}\n"
  fi

  if [ -z "$VALGRIND_CMD" ]; then
    printf "${BB}Leaks:${RC} ${YB}not available${RC}\n"
  elif [ "$leak_result" -ne 1 ]; then
    printf "${BB}Leaks:${RC} ${GB}OK${RC}\n"
  else
    printf "${YB}Leaks:${RC} ${RB}KO${RC}\n"
  fi
}

# **************************************************************************** #
#    EXTRA TESTS
# **************************************************************************** #

test_parallel_execution() {
  if [ -z "$TIMEOUT_FULL" ]; then
    printf "${BB}Parallel execution:${RC} ${YB}SKIPPED${RC} - 'timeout' not available\n"
    return
  fi

  exec="$TIMEOUT_FULL ./$NAME"
  start_time=$($DATE_CMD +%s.%N)
  $exec "/dev/random" "cat" "head -n 1" "${out1}" >/dev/null
  end_time=$($DATE_CMD +%s.%N)

  elapsed_time=$(echo "$end_time - $start_time" | $BC_CMD)
  if (($(echo "$elapsed_time < 1" | $BC_CMD -l))); then
    printf "${BB}Parallel execution:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${BB}Parallel execution:${RC} ${RB}KO${RC}\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "Test failed: CONCURRENCY" >>"${log1}"
    echo "Reason: Second command is waiting for first one to finish" >>"${log1}"
    echo "{$TEST_BREAK}" >>"${log1}"
  fi
}

test_zombie_processes() {
  local zombie_count=0

  exec="$TIMEOUT_FULL ./$NAME"
  $exec "${in1}" "sleep 1" "echo test" "${out1}" 2>/dev/null

  sleep 0.5

  zombie_count=$($PS_CMD aux | $GREP_CMD -v grep |
    $GREP_CMD "pipex" | $GREP_CMD -w 'Z' | $WC_CMD -l)

  if [ "$zombie_count" -eq 0 ]; then
    printf "${BB}Zombie processes:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${BB}Zombie processes:${RC} ${RB}KO${RC}\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "Test failed: ZOMBIE PROCESSES" >>"${log1}"
    echo "Reason: Program does not wait for child or replaces main with fork" >>"${log1}"
    echo "{$TEST_BREAK}" >>"${log1}"
  fi
}

test_signal_handling() {
  exec="$TIMEOUT_FULL ./$NAME"
  $exec "${in1}" "echo" "sleep 2" "${out1}" >/dev/null &

  local pid=$!
  sleep 0.2

  kill -SIGINT "$pid"
  wait "$pid"
  local exit_code=$?

  if [ "$exit_code" -eq 130 ]; then
    printf "${BB}Interrupt handling:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${BB}Interrupt handling:${RC} ${RB}KO${RC}\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "Test failed: INTERRUPT HANDLING" >>"${log1}"
    echo "Reason: Program did not exit with code 130 after receiving SIGINT" >>"${log1}"
    echo "Actual exit code: $exit_code" >>"${log1}"
    echo "{$TEST_BREAK}" >>"${log1}"
  fi
}

test_segfault_handling() {
  local segfault_prog="segfault_test"

  cat >"${segfault_prog}.c" <<EOF
#include <stdlib.h>
int main() {
    char *ptr = NULL;
    *ptr = 'x';
    return 0;
}
EOF

  gcc -o "$segfault_prog" "${segfault_prog}.c" 2>/dev/null

  if [ ! -x "./$segfault_prog" ]; then
    printf "${BB}Segfault handling:${RC} ${YB}SKIPPED${RC} - Could not compile test program\n"
    ${RM} "${segfault_prog}.c" "$segfault_prog"
    return
  fi

  exec="$TIMEOUT_FULL ./$NAME"
  $exec "${in1}" "echo hello" "./$segfault_prog" "${out1}" 2>&1
  local exit_code=$?

  if [ "$exit_code" -eq 139 ]; then
    printf "${BB}Segfault handling:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${BB}Segfault handling:${RC} ${RB}KO${RC}\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "Test failed: SEGFAULT HANDLING" >>"${log1}"
    echo "Reason: Program did not exit with code 139 after segfault in second command" >>"${log1}"
    echo "Actual exit code: $exit_code" >>"${log1}"
    echo "{$TEST_BREAK}" >>"${log1}"
  fi

  ${RM} "${segfault_prog}.c" "$segfault_prog"
}

test_outfile_creation() {
  ${RM} ${out1}

  exec="$TIMEOUT_FULL ./$NAME"
  $exec "${in1}" "sleep 1" "echo test" "${out1}" >/dev/null 2>&1 &

  local pid=$!
  $SLEEP_CMD 0.2

  if [ -f "${out1}" ]; then
    printf "${BB}Outfile creation:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${BB}Outfile creation:${RC} ${RB}KO${RC}\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "Test failed: OUTPUT FILE CREATION" >>"${log1}"
    echo "Reason: Output file was not created while first command was running" >>"${log1}"
    echo "{$TEST_BREAK}" >>"${log1}"
  fi

  wait $pid
}

test_invalid_infile() {
  local cmd_script="exec_marker.sh"
  local marker_file="executed_cmd1"

  echo '#!/bin/bash; touch '"$marker_file"'; exit 0' >"$cmd_script"
  chmod +x "$cmd_script"

  exec="$TIMEOUT_FULL ./$NAME"
  $exec "nonexistent" "./$cmd_script" "cat" "${out1}" >/dev/null 2>&1

  if ! [ -f "$marker_file" ]; then
    printf "${BB}Invalid infile:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${BB}Invalid infile:${RC} ${RB}KO${RC}\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "Test failed: EXEC WITH INVALID INPUT FILE" >>"${log1}"
    echo "Reason: First command was executed despite invalid infile" >>"${log1}"
    echo "{$TEST_BREAK}" >>"${log1}"
  fi

  ${RM} "$cmd_script" "$marker_file"
}

test_invalid_outfile() {
  local cmd_script="exec_marker2.sh"
  local marker_file="executed_cmd2"

  echo '#!/bin/bash; touch '"$marker_file"'; exit 0' >"$cmd_script"
  chmod +x "$cmd_script"

  exec="$TIMEOUT_FULL ./$NAME"
  $exec "${in1}" "cat" "./$cmd_script" "${dir1}" >/dev/null 2>&1

  if [ -f "$marker_file" ]; then
    printf "${BB}Invalid outfile:${RC} ${RB}KO${RC}\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "Test failed: EXEC WITH INVALID OUTPUT FILE" >>"${log1}"
    echo "Reason: Second command was executed despite invalid outfile" >>"${log1}"
    echo "{$TEST_BREAK}" >>"${log1}"
  else
    printf "${BB}Invalid outfile:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi

  ${RM} "$cmd_script" "$marker_file"
}

test_message_consistency() {
  local first_output=""
  local current_output=""

  exec="$TIMEOUT_FULL ./$NAME"
  first_output=$($exec "${in1}" "xxx" "/xxx/xxx" "${out1}" 2>&1)

  for _ in $(seq 2 20); do
    current_output=$($exec "${in1}" "xxx" "/xxx/xxx" "${out1}" 2>&1)

    if [ "$current_output" != "$first_output" ]; then
      printf "${BB}Message consistency:${RC} ${RB}KO${RC}\n"
      TESTS_FAILED=$((TESTS_FAILED + 1))
      echo "Test failed: MESSAGE CONSISTENCY" >>"${log1}"
      echo "Reason: Different error outputs for same input, logging done in child process" >>"${log1}"
      echo "Original: $first_output" >>"${log1}"
      echo "Against: $current_output" >>"${log1}"
      echo "${TEST_BREAK}" >>"${log1}"
      return
    fi
  done

  printf "${BB}Message consistency:${RC} ${GB}OK${RC}\n"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

# **************************************************************************** #
#    COMPARE FUNCTION
# **************************************************************************** #

compare_results() {
  local infile="$1"
  local cmd1="$2"
  local cmd2="$3"
  local outfile1="$4"
  local outfile2="$5"
  local title="$6"
  local empty_cmds=0
  local output_result=0

  # Check if testing empty commands
  if [ -z "$(echo "$cmd1" | $TR_CMD -d '[:space:]')" ] ||
    [ -z "$(echo "$cmd2" | $TR_CMD -d '[:space:]')" ]; then
    empty_cmds=1
  fi

  # Run pipex with timeout if available
  exec="$TIMEOUT_FULL ./$NAME"
  pipex_output=$($exec "$infile" "$cmd1" "$cmd2" "$outfile1" 2>&1)
  pipex_exit=$?

  # Update pipex output in case of segfault
  if [ "$pipex_exit" -eq 139 ]; then
    pipex_output="${Y}Segmentation fault (SIGSEGV) (core dumped)${RC}\n"
  fi

  # Run shell with timeout if available, check if empty commands used
  exec="$TIMEOUT_FULL bash -c"
  if [ "$empty_cmds" -eq 1 ]; then
    shell_output=$($exec "< $infile \"$cmd1\" | \"$cmd2\" > $outfile2" 2>&1)
  else
    shell_output=$($exec "< $infile $cmd1 | $cmd2 > $outfile2" 2>&1)
  fi
  shell_exit=$?

  # Check if outputs match, eg. command not found
  error_msg=$(echo "$shell_output" | $SED_CMD -n 's/.*: \(.*\)$/\1/p')
  if [ -n "$pipex_output" ] && [ -n "$shell_output" ]; then
    if ! echo "$pipex_output" | $GREP_CMD -qF "$error_msg"; then
      output_result=1
    fi
  fi

  # Check for output diffs
  diff_output=$($DIFF_CMD "$outfile1" "$outfile2")

  # Check for memory leaks
  leak_output=$(check_leaks "$infile" "$cmd1" "$cmd2" "$outfile1")
  leak_result=$?

  # Print result
  print_test_result

  # Update error log if test did not pass
  if [ "$output_result" -eq 1 ] || [ "$leak_result" -eq 1 ] ||
    { [ -n "$diff_output" ] && [ -w "$outfile1" ]; } ||
    [ "$pipex_exit" -ne "$shell_exit" ]; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    update_error_log "$title"
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi

  TEST_CURRENT=$((TEST_CURRENT + 1))
}

# **************************************************************************** #
#    TEST RUNNERS
# **************************************************************************** #

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
  compare_results "${in1}" "ls" "wc" "${dir1}" "${dir1}" "OUTFILE IS FOLDER, VALID CMDS"
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
  compare_results "${in1}" "$LS_CMD" "wc" "${out1}" "${out2}" "NO PATH ENVP, VALID CMD1 (ABS), INVALID CMD2"
  compare_results "${in1}" "$LS_CMD" "$CAT_CMD" "${out1}" "${out2}" "NO PATH ENVP, VALID CMDS (ABS)"
  export PATH="$OLD_PATH"
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
  compare_results $infile "$LS_CMD" "$CAT_CMD" "${out1}" "${out2}" "LS CMD1 (ABS), CAT CMD2 (ABS)"
}

run_extra_tests() {
  print_header "EXTRA TESTS"
  test_parallel_execution
  test_signal_handling
  test_segfault_handling
  test_zombie_processes
  test_outfile_creation
  test_invalid_infile
  test_invalid_outfile
  test_message_consistency
}

# **************************************************************************** #
#    MAIN RUNNER
# **************************************************************************** #

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
