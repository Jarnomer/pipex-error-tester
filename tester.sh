#!/bin/bash

source "$(dirname "$0")/variables.sh"
source "$(dirname "$0")/extras.sh"
source "$(dirname "$0")/utils.sh"

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
  if [ "$ALL_ERROR_TESTS" -eq 0 ]; then
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

run_error_tests() {
  print_header "ERROR TESTS"
  compare_results "noinfile" "ls" "wc" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "noinfile" "xxx" "wc" "${out1}" "${out2}" "$(get_error_title)"

  chmod -r ${in1}
  compare_results "${in1}" "ls" "wc" "${out1}" "${out2}" "$(get_error_title)"
  chmod +r ${in1}

  chmod -w ${out1}
  chmod -w ${out2}
  compare_results "${in1}" "ls" "wc" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "ls" "wc" "${dir1}" "${dir1}" "$(get_error_title)"
  chmod +w ${out1}
  chmod +w ${out2}

  chmod -x ${bin1}
  compare_results "${in1}" "./${bin1}" "wc" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "wc" "./${bin1}" "${out1}" "${out2}" "$(get_error_title)"
  chmod +x ${bin1}

  compare_results "${in1}" "./${dir1}/" "ls" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "ls" "./${dir1}/" "${out1}" "${out2}" "$(get_error_title)"

  compare_results "${in1}" "xxx" "wc" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "/xxx/xxx" "wc" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "ls" "xxx" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "ls" "/xxx/xxx" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "xxx" "/xxx/xxx" "${out1}" "${out2}" "$(get_error_title)"

  compare_results "${in1}" "" "wc" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "ls" "     " "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "" "     " "${out1}" "${out2}" "$(get_error_title)"

  compare_results "${in1}" "ls -?" "grep c" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "ls -?" "wc -9001" "${out1}" "${out2}" "$(get_error_title)"

  unset PATH
  compare_results "${in1}" "ls" "wc" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "/xxx/xxx" "/xxx/xxx" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "$LS_CMD" "wc" "${out1}" "${out2}" "$(get_error_title)"
  compare_results "${in1}" "$LS_CMD" "$CAT_CMD" "${out1}" "${out2}" "$(get_error_title)"
  export PATH="$OLD_PATH"
}

run_valid_tests() {
  print_header "VALID TESTS"
  local infile="Makefile"
  local count=$(get_valid_title count)
  TEST_CURRENT=1

  for ((i = 1; i <= count; i++)); do
    local title="$(get_valid_title)"
    local lowercased=$(echo "$title" | tr '[:upper:]' '[:lower:]')
    local cmd1=$(echo "$lowercased" | sed 's/ and .*//')
    local cmd2=$(echo "$lowercased" | sed 's/.* and //')

    >"${out1}" # Clean output files
    >"${out2}"

    compare_results "$infile" "$cmd1" "$cmd2" "${out1}" "${out2}" "$title"
  done
}

run_special_tests() {
  print_header "SPECIAL TESTS"
  local infile="Makefile"
  local count=$(get_special_title count)
  TEST_CURRENT=1

  for ((i = 1; i <= count; i++)); do
    local title="$(get_special_title)"
    local cmd1=$(echo "$title" | sed 's/ | .*//')
    local cmd2=$(echo "$title" | sed 's/.* | //')

    >"${out1}" # Clean output files
    >"${out2}"

    compare_results "$infile" "$cmd1" "$cmd2" "${out1}" "${out2}" "$title"
  done
}

run_extra_tests() {
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
  local count=$(get_error_title count)

  while [[ $# -gt 0 ]]; do
    case $1 in
    -t | --test)
      if [ -n "$2" ] && [[ $2 != -* ]]; then
        if [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -gt 0 ] && [ "$2" -le "$count" ]; then
          SELECTED_TESTS="$SELECTED_TESTS $2"
          ALL_ERROR_TESTS=0
        else
          printf "${RB}Error:${RC} Invalid test number: ${YB}%s${RC}\n" "$2"
          printf "${GB}Valid:${RC} Test numbers: ${GB}1${RC} and ${GB}%s${RC}\n" "$count"
          exit 1
        fi
        shift 2
      else
        printf "${RB}Error:${RC} Argument ${YB}<TEST_ID>${RC} is missing\n"
        exit 1
      fi
      ;;
    -v | --valid)
      VALID_TESTS=1
      shift
      ;;
    -s | --special)
      SPECIAL_TESTS=1
      shift
      ;;
    -e | --extra)
      EXTRA_TESTS=1
      shift
      ;;
    -l | --list)
      print_tests
      exit 0
      ;;
    -h | --help)
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
  elif [ $VALID_TESTS -eq 1 ]; then
    run_valid_tests
  elif [ $SPECIAL_TESTS -eq 1 ]; then
    run_special_tests
  else
    run_error_tests
  fi
  print_summary
  cleanup
else
  printf "${RB}ERROR: ${RC}${Y}binary <$NAME> not found${RC}\n"
  exit 1
fi
