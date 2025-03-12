#!/bin/bash

source "$(dirname "$0")/variables.sh"

get_error_title() {
  local error_titles=(
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
    echo "${#error_titles[@]}"
  else
    echo "${error_titles[$TEST_CURRENT - 1]}"
  fi
}

get_valid_title() {
  local valid_titles=(
    "ls | wc"
    "cat | wc -w"
    "grep o | wc -l"
    "cat | sort"
    "cat | head -5"
    "cat | tail -3"
    "head -10 | grep m"
    "cat | uniq"
    "ls | grep .c"
    "find . -type f | sort"
    "cat | tr a-z a-z"
    "cat | cut -d: -f1"
  )
  if [ "$1" = "count" ]; then
    echo "${#valid_titles[@]}"
  else
    echo "${valid_titles[$TEST_CURRENT - 1]}"
  fi
}

get_extra_title() {
  local extra_titles=(
    "PARALLEL EXECUTION"
    "INTERRUPT HANDLING"
    "SEGFAULT IN CMD2"
    "INVALID INFILE"
    "INVALID OUTFILE"
    "OUTFILE CREATION"
    "MESSAGE CONSISTENCY"
    "ZOMBIE PROCESSES"
  )
  if [ "$1" = "count" ]; then
    echo "${#extra_titles[@]}"
  else
    echo "${extra_titles[$TEST_CURRENT - 1]}"
  fi
}

get_bonus_title() {
  local bonus_titles=(
    "ls | xxx | cat | wc"
    "cat | grep a | /xxx/xxx | sort"
    "grep a | sort | cat | xxx -l"
    "cat | head | grep a | tail | /xxx/xxx"
    "ps | grep a | ls -? | sort | uniq"
    "ls -Z | grep c | wc -l"
    "ls -la | grep c | wc -l | sort"
    "cat | head -n 5 | grep a | wc -l"
    "find . -type f | grep c | sort | head -n 3"
    "ls | grep c | sort -r | head -n 2 | wc -l"
    "cat | tr a-z A-Z | grep A | wc -c"
    "ls -l | awk {print} | grep c | sort -r"
    "find . | grep c | sort | uniq | wc -l"
    "cat | head -n 10 | tail -n 5 | grep a | wc"
    "ls | grep -v a | sort -n | head -n 3 | cat"
  )
  if [ "$1" = "count" ]; then
    echo "${#bonus_titles[@]}"
  else
    echo "${bonus_titles[$TEST_CURRENT - 1]}"
  fi
}

get_bonus_extra_title() {
  local bonus_extra_titles=(
    "ARGUMENTS COUNT"
    "HEREDOC LIMITER"
    "HEREDOC APPEND"
    "INFILE TRUNCATE"
    "ZOMBIE PROCESSES"
  )
  if [ "$1" = "count" ]; then
    echo "${#bonus_extra_titles[@]}"
  else
    echo "${bonus_extra_titles[$TEST_CURRENT - 1]}"
  fi
}

get_special_title() {
  local special_titles=(
    "grep -v '^#' | cut -d' ' -f1,2"
    "grep -Eo '[A-Z][A-Za-z0-9_]*' | sort -u"
    "sed -E 's/(\\w+)=/\\1: /g; s/#.*//g' | grep -i 'make'"
    "grep -E '^[a-zA-Z]' | tr '[:lower:]' '[:upper:]'"
    "sed -E 's/\t/ /g' | grep -o '[0-9]\\+'"
    "grep 'include' | sed -E 's/.*<(.*)>.*/\\1/'"
    "cut -d'=' -f1 | sed 's/[[:space:]]*$//'"
    "awk '/^#/ {next} {print}' | sort -r"
  )
  if [ "$1" = "count" ]; then
    echo "${#special_titles[@]}"
  else
    echo "${special_titles[$TEST_CURRENT - 1]}"
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
  make fclean >/dev/null
  ${RM_CMD} ${in1} ${out1} ${out2} ${bin1} ${dir1}
  if [ -f "$log1" ] && [ ! -s "$log1" ]; then
    ${RM_CMD} "$log1" # remove log if empty
  fi
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

check_bonus_rule() {
  if grep -q "^bonus:" Makefile; then
    echo "1"
  else
    echo "0"
  fi
}

check_leaks() {
  local has_leaks=0
  local open_fds=0

  base_cmd=$(echo "$1" | $SED_CMD "s|$TIMEOUT_FULL ||")
  valgrind_cmd="$VALGRIND_FULL --log-file=/dev/stdout $base_cmd"

  leak_output=$(eval "$valgrind_cmd" 2>/dev/null)

  open_fds=$(echo "$leak_output" | $GREP_CMD -A 1 "FILE DESCRIPTORS" |
    $GREP_CMD -o '[0-9]\+ open' | $GREP_CMD -o '[0-9]\+' | $SORT_CMD -nr | $HEAD_CMD -1)

  definitely_lost=$(echo "$leak_output" |
    $GREP_CMD -o 'definitely lost: [0-9,]\+ bytes' | $GREP_CMD -o '[0-9,]\+')
  indirectly_lost=$(echo "$leak_output" |
    $GREP_CMD -o 'indirectly lost: [0-9,]\+ bytes' | $GREP_CMD -o '[0-9,]\+')

  if [[ -n "$definitely_lost" && "$definitely_lost" != "0" ]] ||
    [[ -n "$indirectly_lost" && "$indirectly_lost" != "0" ]] ||
    { [ -n "$open_fds" ] && [ "$open_fds" -gt 3 ]; }; then
    has_leaks=1
  fi

  echo "$leak_output"
  return $has_leaks
}

print_usage() {
  printf "\n${CB}Usage:${RC} %s ${GB}[OPTIONS]${RC}\n\n" "$0"
  printf "${GB}Options:${RC}\n"
  printf "  ${GB}-t${RC}, ${G}--test ID  ${P}Run specific error test by ID${RC}\n"
  printf "  ${GB}-v${RC}, ${G}--valid    ${P}Run tests with valid commands${RC}\n"
  printf "  ${GB}-e${RC}, ${G}--extra    ${P}Run extra checks and logical tests${RC}\n"
  printf "  ${GB}-b${RC}, ${G}--bonus    ${P}Run hdoc and multi pipeline tests${RC}\n"
  printf "  ${GB}-s${RC}, ${G}--special  ${P}Run tests with meta characters${RC}\n"
  printf "  ${GB}-a${RC}, ${G}--all      ${P}Run all but special tests${RC}\n"
  printf "  ${GB}-l${RC}, ${G}--list     ${P}List all available tests${RC}\n"
  printf "  ${GB}-h${RC}, ${G}--help     ${P}Show this help message${RC}\n\n"
}

print_tests() {
  count=$(get_error_title count)

  print_header "ERROR TESTS"
  for ((i = 1; i <= count; i++)); do
    printf "${PB}%2d${RC} - ${G}%s${RC}\n" "$TEST_CURRENT" "$(get_error_title)"
    TEST_CURRENT=$((TEST_CURRENT + 1))
  done

  TEST_CURRENT=1
  count=$(get_valid_title count)

  print_header "VALID TESTS"
  for ((i = 1; i <= count; i++)); do
    printf "${PB}%2d${RC} - ${G}%s${RC}\n" "$TEST_CURRENT" "$(get_valid_title)"
    TEST_CURRENT=$((TEST_CURRENT + 1))
  done

  TEST_CURRENT=1
  count=$(get_extra_title count)

  print_header "EXTRA TESTS"
  for ((i = 1; i <= count; i++)); do
    printf "${PB}%2d${RC} - ${G}%s${RC}\n" "$TEST_CURRENT" "$(get_extra_title)"
    TEST_CURRENT=$((TEST_CURRENT + 1))
  done

  TEST_CURRENT=1
  count=$(get_bonus_title count)

  print_header "BONUS TESTS"
  for ((i = 1; i <= count; i++)); do
    printf "${PB}%2d${RC} - ${G}%s${RC}\n" "$TEST_CURRENT" "$(get_bonus_title)"
    TEST_CURRENT=$((TEST_CURRENT + 1))
  done

  TEST_CURRENT=1
  count=$(get_bonus_extra_title count)

  print_header "BONUS EXTRA TESTS"
  for ((i = 1; i <= count; i++)); do
    printf "${PB}%2d${RC} - ${G}%s${RC}\n" "$TEST_CURRENT" "$(get_bonus_extra_title)"
    TEST_CURRENT=$((TEST_CURRENT + 1))
  done

  TEST_CURRENT=1
  count=$(get_special_title count)

  print_header "SPECIAL TESTS"
  for ((i = 1; i <= count; i++)); do
    printf "${PB}%2d${RC} - ${G}%s${RC}\n" "$TEST_CURRENT" "$(get_special_title)"
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
