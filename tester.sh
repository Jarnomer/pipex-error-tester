#!/bin/bash

source "$(dirname "$0")/variables.sh"
source "$(dirname "$0")/extras.sh"
source "$(dirname "$0")/bonus.sh"
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
  pipex_cmd=$(echo "$pipex_cmd" | $SED_CMD "s|$TIMEOUT_FULL ||")

  printf "${CB}Pipex:${RC} $pipex_cmd\n"
  printf "${CB}Shell:${RC} $shell_cmd\n\n"

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
  local outfile1="$2"
  local outfile2="$3"
  local title="$4"
  local output_result=0
  local empty_cmds=0
  local commands=()

  # Skip test if not selected
  if [ "$ALL_ERROR_TESTS" -eq 0 ]; then
    if ! echo "$SELECTED_TESTS" | $GREP_CMD -q "\b$TEST_CURRENT\b"; then
      TEST_CURRENT=$((TEST_CURRENT + 1))
      return
    fi
  fi

  # Collect all commands
  for ((i = 5; i <= $#; i++)); do
    commands+=("${!i}")
  done

  # Check if testing empty commands
  for cmd in "${commands[@]}"; do
    if [ -z "$(echo "$cmd" | $TR_CMD -d '[:space:]')" ]; then
      empty_cmds=1
      break
    fi
  done

  # Build full pipex command
  exec="$TIMEOUT_FULL ./$NAME"
  pipex_cmd="$exec \"$infile\""
  for cmd in "${commands[@]}"; do
    pipex_cmd+=" \"$cmd\""
  done
  pipex_cmd+=" \"$outfile1\""

  # Execute pipex command
  pipex_output=$(eval $pipex_cmd 2>&1)
  pipex_exit=$?

  # Build full shell command
  if [ "$empty_cmds" -eq 1 ]; then
    shell_cmd="< $infile \"${commands[0]}\""
    for ((i = 1; i < ${#commands[@]}; i++)); do
      shell_cmd+=" | \"${commands[$i]}\""
    done
  else
    shell_cmd="< $infile ${commands[0]}"
    for ((i = 1; i < ${#commands[@]}; i++)); do
      shell_cmd+=" | ${commands[$i]}"
    done
  fi
  shell_cmd+=" > $outfile2"

  # Execute shell command
  exec="$TIMEOUT_FULL bash -c"
  shell_output=$($exec "$shell_cmd" 2>&1)
  shell_exit=$?

  # Update pipex output in case of segfault
  if [ "$pipex_exit" -eq 139 ]; then
    pipex_output="${Y}Segmentation fault (SIGSEGV) (core dumped)${RC}\n"
  fi

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
  leak_output=$(check_leaks "$pipex_cmd")
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

  compare_results "noinfile" "${out1}" "${out2}" "$(get_error_title)" "ls" "wc"
  compare_results "noinfile" "${out1}" "${out2}" "$(get_error_title)" "xxx" "wc"

  chmod -r ${in1}
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "ls" "wc"
  chmod +r ${in1}

  chmod -w ${out1}
  chmod -w ${out2}
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "ls" "wc"
  compare_results "${in1}" "${dir1}" "${dir1}" "$(get_error_title)" "ls" "wc"
  chmod +w ${out1}
  chmod +w ${out2}

  chmod -x ${bin1}
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "./${bin1}" "wc"
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "wc" "./${bin1}"
  chmod +x ${bin1}

  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "./${dir1}/" "ls"
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "ls" "./${dir1}/"

  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "xxx" "wc"
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "/xxx/xxx" "wc"
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "ls" "xxx"
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "ls" "/xxx/xxx"
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "xxx" "/xxx/xxx"

  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "" "wc"
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "ls" "     "
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "" "     "

  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "ls -?" "grep c"
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "ls -?" "wc -9001"

  unset PATH
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "ls" "wc"
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "/xxx/xxx" "/xxx/xxx"
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "$LS_CMD" "wc"
  compare_results "${in1}" "${out1}" "${out2}" "$(get_error_title)" "$LS_CMD" "$CAT_CMD"
  export PATH="$OLD_PATH"
}

run_tester() {
  local header_title="$1"
  local get_function="$2"
  local infile="Makefile"
  TEST_CURRENT=1

  print_header "$header_title"

  count=$($get_function count)
  while [ $TEST_CURRENT -le $count ]; do
    local title="$($get_function)"

    >"${out1}" # Reset output files
    >"${out2}"

    # Process commands from title
    IFS='|' read -r -a commands <<<"$title"

    # Join commands and base arguments
    if [ ${#commands[@]} -ge 1 ]; then
      args=("$infile" "${out1}" "${out2}" "$title")
      for cmd in "${commands[@]}"; do
        cmd=$(echo "$cmd" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        args+=("$cmd")
      done
      compare_results "${args[@]}"
    else
      printf "${RB}ERROR:${RC} ${Y}Incorrect test line format${RC}\n"
    fi
  done
}

parse_arguments() {
  count=$(get_error_title count)

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
    -e | --extra)
      EXTRA_TESTS=1
      shift
      ;;
    -b | --bonus)
      BONUS_TESTS=1
      shift
      ;;
    -s | --special)
      SPECIAL_TESTS=1
      shift
      ;;
    -a | --all)
      ALL_TESTS=1
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
  printf "\n${CB}INFO: ${RC}Running ${GB}Makefile${RC}...\n"
  make >/dev/null
fi

if [ -f "$NAME" ]; then
  check_requirements
  setup_test_files
  if [ $ALL_TESTS -eq 1 ]; then
    run_error_tests
    run_tester "VALID TESTS" "get_valid_title"
    run_extra_tests
    if [ "$(check_bonus_rule)" -eq 1 ]; then
      run_tester "BONUS TESTS" "get_bonus_title"
      run_extra_bonus_tests
    else
      printf "\n${CB}INFO:${RC} No ${YB}<bonus>${RC} rule in Makefile\n"
    fi
  elif [ $VALID_TESTS -eq 1 ]; then
    run_tester "VALID TESTS" "get_valid_title"
  elif [ $EXTRA_TESTS -eq 1 ]; then
    run_extra_tests
  elif [ $BONUS_TESTS -eq 1 ]; then
    if [ "$(check_bonus_rule)" -eq 1 ]; then
      run_tester "BONUS TESTS" "get_bonus_title"
      run_extra_bonus_tests
    else
      printf "\n${CB}INFO:${RC} No ${YB}<bonus>${RC} rule in Makefile\n"
    fi
  elif [ $SPECIAL_TESTS -eq 1 ]; then
    run_tester "SPECIAL TESTS" "get_special_title"
  else
    run_error_tests
  fi
  print_summary
  cleanup
else
  printf "${RB}ERROR: ${RC}${Y}binary <$NAME> not found${RC}\n"
  exit 1
fi
