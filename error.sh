#!/bin/bash

source "$(dirname "$0")/variables.sh"
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
