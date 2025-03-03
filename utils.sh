#!/bin/bash

source "$(dirname "$0")/variables.sh"

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

print_usage() {
  printf "\n${CB}Usage:${RC} %s [OPTIONS]\n\n" "$0"
  printf "${GB}Options:${RC}\n"
  printf "  -t, --test TEST_ID    Run specific test by ID\n"
  printf "  -l, --list            List all available tests\n"
  printf "  -h, --help            Show this help message\n\n"
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
