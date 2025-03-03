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
EXTRA_TESTS=0

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

# **************************************************************************** #
# UTILITIES
# **************************************************************************** #

get_title() {
  local titles=(
    "INFILE DOES NOT EXIST"
    "INFILE DOES NOT EXIST, INVALID CMD1"
    "INFILE NO READ PERMISSION, VALID CMDS"
    "OUTFILE NO WRITE PERMISSION, VALID CMDS"
    "OUTFILE IS FOLDER, VALID CMDS"
    "NO EXEC PERMISSION CMD1"
    "NO EXEC PERMISSION CMD2"
    "CMD1 IS FOLDER, VALID CMD2"
    "VALID CMD1, CMD2 IS FOLDER"
    "INVALID CMD1, VALID CMD2"
    "INVALID CMD1 (ABS), VALID CMD2"
    "VALID CMD1, INVALID CMD2"
    "VALID CMD1, INVALID CMD2 (ABS)"
    "INVALID CMD1, INVALID CMD2 (ABS)"
    "NULL STRING CMD1, VALID CMD2"
    "VALID CMD1, EMPTY CMD2"
    "NULL STRING CMD1, EMPTY CMD2"
    "BAD ARGS CMD1, VALID CMD2"
    "BAD ARGS CMD1, BAD ARGS CMD2"
    "NO PATH ENVP, INVALID CMDS"
    "NO PATH ENVP, INVALID CMDS (ABS)"
    "NO PATH ENVP, VALID CMD1 (ABS), INVALID CMD2"
    "NO PATH ENVP, VALID CMDS (ABS)"
  )
  if [ "$1" = "count" ]; then
    echo "${#titles[@]}"
  else
    echo "${titles[$TEST_CURRENT - 1]}"
  fi
}

print_usage() {
  printf "\n${CB}Usage:${RC} %s [OPTIONS]\n\n" "$0"
  printf "${GB}Options:${RC}\n"
  printf "  -t, --test TEST_ID    Run specific test by ID\n"
  printf "  -e, --extra           Run separate extra tests\n"
  printf "  -l, --list            List all available tests\n"
  printf "  -h, --help            Show this help message\n\n"
}

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
  ${RM_CMD} ${in1} ${out1} ${out2} ${bin1} ${dir1}
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
  echo -n >"${log1}"   # Reset log file
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

print_tests() {
  local total_tests=$(get_title count)

  for ((i=1; i<=total_tests; i++)); do
    printf "${PB}%2d${RC} - %s\n" "$TEST_CURRENT" "$(get_title)"
    TEST_CURRENT=$((TEST_CURRENT + 1))
  done
}

print_title() {
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

# **************************************************************************** #
# RESULT PRINT AND LOG
# **************************************************************************** #

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
    echo "Output: KO - Different" >>"${log1}"
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

print_result() {
  print_title "$title"

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
    [[ "$shell_output" == *"invalid"* ]] && printf "\n"
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

  if [ -z "$VALGRIND_FULL" ]; then
    printf "${BB}Leaks:${RC} ${YB}not available${RC}\n"
  elif [ "$leak_result" -ne 1 ]; then
    printf "${BB}Leaks:${RC} ${GB}OK${RC}\n"
  else
    printf "${YB}Leaks:${RC} ${RB}KO${RC}\n"
  fi
}

# **************************************************************************** #
# EXTRA TESTS
# **************************************************************************** #

test_parallel_execution() {
  local title="Parallel execution"
  local reason="Second command is waiting for first one to execute"

  if [ -z "$TIMEOUT_FULL" ]; then
    printf "${BB}$title:${RC} ${Y}Skipped${RC} - 'timeout' not available\n"
    return
  fi

  exec="$TIMEOUT_FULL ./$NAME"
  start_time=$(date +%s.%N)
  $exec "/dev/random" "cat" "head -n 1" "${out1}" >/dev/null
  end_time=$(date +%s.%N)

  elapsed_time=$(echo "$end_time - $start_time" | bc)
  if (($(echo "$elapsed_time < 1" | bc -l))); then
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${YB}$title:${RC} ${RB}KO${RC} - $reason\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_zombie_processes() {
  local title="Zombie processes"
  local reason="Program exits leaving zombie process into process table"
  local zombie_count=0

  exec="$TIMEOUT_FULL ./$NAME"
  $exec "${in1}" "sleep 0.5" "echo test" "${out1}" 2>/dev/null

  sleep 0.2

  zombie_count=$(ps aux | grep -v grep | grep "pipex" | grep -w 'Z' | wc -l)

  if [ "$zombie_count" -eq 0 ]; then
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${YB}$title:${RC} ${RB}KO${RC} - $reason\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_signal_handling() {
  local title="Interrupt handling"
  local reason="Program did not exit with code 130 after being interrupted"

  exec="$TIMEOUT_FULL ./$NAME"
  $exec "${in1}" "echo test" "sleep 2" "${out1}" >/dev/null &

  local pid=$!
  sleep 0.2

  kill -SIGINT "$pid"
  wait "$pid"
  local exit_code=$?

  if [ "$exit_code" -eq 130 ]; then
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${YB}$title:${RC} ${RB}KO${RC} - $reason\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_segfault_handling() {
  local title="Segfault handling"
  local reason="Program did not exit with code 139 after segfault in second command"
  local segfault_prog="segfault_test"

  if ! command -v gcc >/dev/null 2>&1; then
    printf "${BB}$title:${RC} ${Y}Skipped${RC} - 'gcc' not available\n"
    return
  fi

  cat >"${segfault_prog}.c" <<EOF
#include <stdlib.h>
int main() {
    char *ptr = NULL;
    *ptr = 'x';
    return 0;
}
EOF

  gcc -o "$segfault_prog" "${segfault_prog}.c" 2>/dev/null

  exec="$TIMEOUT_FULL ./$NAME"
  $exec "${in1}" "echo test" "./$segfault_prog" "${out1}" 2>&1
  local exit_code=$?

  if [ "$exit_code" -eq 139 ]; then
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${YB}$title:${RC} ${RB}KO${RC} - $reason\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  ${RM_CMD} "${segfault_prog}.c" "$segfault_prog"
}

test_outfile_creation() {
  local title="Outfile creation"
  local reason="Output file was not created during execution of first command"

  ${RM_CMD} ${out1}
  exec="$TIMEOUT_FULL ./$NAME"
  $exec "${in1}" "sleep 1" "echo test" "${out1}" >/dev/null 2>&1 &

  local pid=$!
  sleep 0.2

  if [ -f "${out1}" ]; then
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${YB}$title:${RC} ${RB}KO${RC} - $reason\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  wait $pid
}

test_invalid_infile() {
  local title="Invalid infile"
  local reason="First command was executed without valid infile"

  local cmd_script="exec_marker.sh"
  local marker_file="executed_cmd1"

  echo '#!/bin/bash; touch '"$marker_file"'; exit 0' >"$cmd_script"
  chmod +x "$cmd_script"

  exec="$TIMEOUT_FULL ./$NAME"
  $exec "nonexistent" "./$cmd_script" "cat" "${out1}" >/dev/null 2>&1

  if ! [ -f "$marker_file" ]; then
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${YB}$title:${RC} ${RB}KO${RC} - $reason\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  ${RM_CMD} "$cmd_script" "$marker_file"
}

test_invalid_outfile() {
  local title="Invalid outfile"
  local reason="Second command was executed without valid outfile"

  local cmd_script="exec_marker2.sh"
  local marker_file="executed_cmd2"

  echo '#!/bin/bash; touch '"$marker_file"'; exit 0' >"$cmd_script"
  chmod +x "$cmd_script"

  exec="$TIMEOUT_FULL ./$NAME"
  $exec "${in1}" "cat" "./$cmd_script" "${dir1}" >/dev/null 2>&1

  if [ -f "$marker_file" ]; then
    printf "${YB}$title:${RC} ${RB}KO${RC} - $reason\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi

  ${RM_CMD} "$cmd_script" "$marker_file"
}

test_message_consistency() {
  local title="Message Consistency"
  local reason="Error outputs are not consistent across multiple executions"

  local first_output=""
  local current_output=""

  exec="$TIMEOUT_FULL ./$NAME"
  first_output=$($exec "${in1}" "xxx" "/xxx/xxx" "${out1}" 2>&1)

  for _ in $(seq 2 20); do
    current_output=$($exec "${in1}" "xxx" "/xxx/xxx" "${out1}" 2>&1)
    if [ "$current_output" != "$first_output" ]; then
      printf "${YB}$title:${RC} ${RB}KO${RC}\n"
      printf "${YB}$title:${RC} $reason\n"
      TESTS_FAILED=$((TESTS_FAILED + 1))
      return
    fi
  done

  printf "${BB}$title:${RC} ${GB}OK${RC}\n"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

# **************************************************************************** #
# TEST FUNCTION
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

  # Skip test if not selected
  if [ "$ALL_TESTS" -eq 0 ]; then
    if ! echo "$SELECTED_TESTS" | $GREP_CMD -q "\b$TEST_CURRENT\b"; then
      TEST_CURRENT=$((TEST_CURRENT + 1))
      return
    fi
  fi

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
  print_result

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
# ERROR TESTS
# **************************************************************************** #

run_error_tests() {
  print_header "ERROR TESTS"
  compare_results "noinfile" "ls" "wc" "${out1}" "${out2}" "$(get_title)"
  compare_results "noinfile" "xxx" "wc" "${out1}" "${out2}" "$(get_title)"

  chmod -r ${in1}
  compare_results "${in1}" "ls" "wc" "${out1}" "${out2}" "$(get_title)"
  chmod +r ${in1}

  chmod -w ${out1}
  chmod -w ${out2}
  compare_results "${in1}" "ls" "wc" "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "ls" "wc" "${dir1}" "${dir1}" "$(get_title)"
  chmod +w ${out1}
  chmod +w ${out2}

  chmod -x ${bin1}
  compare_results "${in1}" "./${bin1}" "wc" "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "wc" "./${bin1}" "${out1}" "${out2}" "$(get_title)"
  chmod +x ${bin1}

  compare_results "${in1}" "./${dir1}/" "ls" "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "ls" "./${dir1}/" "${out1}" "${out2}" "$(get_title)"

  compare_results "${in1}" "xxx" "wc" "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "/xxx/xxx" "wc" "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "ls" "xxx" "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "ls" "/xxx/xxx" "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "xxx" "/xxx/xxx" "${out1}" "${out2}" "$(get_title)"

  compare_results "${in1}" "" "wc" "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "ls" "     " "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "" "     " "${out1}" "${out2}" "$(get_title)"

  compare_results "${in1}" "ls -?" "grep c" "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "ls -?" "wc -9001" "${out1}" "${out2}" "$(get_title)"

  unset PATH
  compare_results "${in1}" "ls" "wc" "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "/xxx/xxx" "/xxx/xxx" "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "$LS_CMD" "wc" "${out1}" "${out2}" "$(get_title)"
  compare_results "${in1}" "$LS_CMD" "$CAT_CMD" "${out1}" "${out2}" "$(get_title)"
  export PATH="$OLD_PATH"
}

# **************************************************************************** #
# MAIN
# **************************************************************************** #

run_extra_tests() {
  echo "Starting test_parallel_execution..."
  print_header "EXTRA TESTS"
  setup_test_files
  test_parallel_execution
  test_signal_handling
  test_segfault_handling
  test_zombie_processes
  test_outfile_creation
  test_invalid_infile
  test_invalid_outfile
  test_message_consistency
  cleanup
}

parse_arguments() {
  local cnt=$(get_title count)
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      -t|--test)
        if [ -n "$2" ] && [[ $2 != -* ]]; then
          if [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -gt 0 ] && [ "$2" -le "$cnt" ]; then
            SELECTED_TESTS="$SELECTED_TESTS $2"
            ALL_TESTS=0
          else
            printf "${RB}Error:${RC} Invalid test number: ${YB}%s${RC}\n" "$2"
            printf "${GB}Valid:${RC} Test numbers: ${GB}1${RC} and ${GB}%s${RC}\n" "$cnt"
            exit 1
          fi
          shift 2
        else
          printf "${RB}Error:${RC} Argument ${YB}<TEST_ID>${RC} is missing\n"
          exit 1
        fi
        ;;
      -e|--extra)
        EXTRA_TESTS=1
        shift
        ;;
      -l|--list)
        print_tests
        exit 0
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        printf "${RB}Error:${RC} Unknown option %s\n" "$1"
        print_usage
        exit 1
        ;;
    esac
  done
}

trap handle_ctrlc SIGINT

parse_arguments "$@"

if ! [ -f "$NAME" ]; then
  printf "\n${CB}INFO: ${RC}Binary ${YB}<$NAME>${RC} not found...\n"
  printf "\n${CB}INFO: ${RC}Running ${CB}Makefile${RC}...\n"
  make >/dev/null
fi

if [ -f "$NAME" ]; then
  check_requirements
  setup_test_files
  if [ $EXTRA_TESTS -eq 1 ]; then
    run_extra_tests
  else
    run_error_tests
  fi
  print_summary
  cleanup
else
  printf "${RB}ERROR: ${RC}${Y}binary <$NAME> not found${RC}\n"
  exit 1
fi
