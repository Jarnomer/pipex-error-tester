#!/bin/bash

source "$(dirname "$0")/variables.sh"

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
  $exec "${in1}" "sleep 1" "echo test" "${out1}" 2>/dev/null

  sleep 0.5

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
  $exec "${in1}" "echo" "sleep 2" "${out1}" >/dev/null &

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
  $exec "${in1}" "echo hello" "./$segfault_prog" "${out1}" 2>&1
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
      printf "${YB}$title:${RC} ${RB}KO${RC} - $reason\n"
      TESTS_FAILED=$((TESTS_FAILED + 1))
      return
    fi
  done

  printf "${BB}$title:${RC} ${GB}OK${RC}\n"
  TESTS_PASSED=$((TESTS_PASSED + 1))
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
