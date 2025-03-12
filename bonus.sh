#!/bin/bash

source "$(dirname "$0")/variables.sh"
source "$(dirname "$0")/utils.sh"

test_heredoc_limiter() {
  local title="Heredoc limiter" # Only "EOF" is valid eof
  eofs=("EOF " " EOF" "EEOF" "EOFF" "eof" "\tEOF" "EOF\n")
  test="Test line 1\nTest line 2\nEOF\n"
  marker="42"

  exec="$TIMEOUT_FULL ./$NAME"
  for eof in "${eofs[@]}"; do
    rm ${out1}
    echo -e "$test$marker" | $exec "here_doc" "$eof" "cat" "${out1}" >/dev/null 2>&1

    # Marker should be present in output if EOF wasn't recognized
    if ! grep -q "$marker" "${out1}"; then
      printf "${YB}$title:${RC} ${RB}KO${RC} - \"${eof}\" was recognized as limiter\n"
      TESTS_FAILED=$((TESTS_FAILED + 1))
      return
    fi
  done

  printf "${BB}$title:${RC} ${GB}OK${RC}\n"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_heredoc_append() {
  local title="Heredoc append"
  local reason="Outfile is not appended with heredoc"
  local test="Test line 1\nTest line 2\nEOF\n"

  rm ${out1}
  exec="$TIMEOUT_FULL ./$NAME"
  for i in $(seq 1 5); do
    echo -e "$test" | $exec "here_doc" "EOF" "cat" "${out1}" >/dev/null 2>&1
  done

  if [ "$(wc -l <"${out1}")" -eq 10 ]; then
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${YB}$title:${RC} ${RB}KO${RC} - $reason\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_infile_truncate() {
  local title="Infile truncate"
  local reason="Outfile is not truncated without heredoc"
  local test="Test line 1"

  rm ${out1}
  echo "$test" >"${in1}"
  exec="$TIMEOUT_FULL ./$NAME"
  for i in $(seq 1 5); do
    echo "$test" | $exec "${in1}" "cat" "cat" "${out1}" >/dev/null 2>&1
  done

  if [ "$(wc -l <"${out1}")" -eq 1 ]; then
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${YB}$title:${RC} ${RB}KO${RC} - $reason\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_file_descriptors() {
  local title="File descriptors"
  local reason="Program didn't handle fd limit: "

  cats_above=""

  system_limit=$(ulimit -n)
  if [ -z "$system_limit" ] || [ "$system_limit" -eq 0 ]; then
    printf "${BB}$title:${RC} ${YB}Skipped${RC} - Could not get system fd limit\n"
    return
  fi

  # stdin, stdout, stderr, infile, outfile + 2 fds per command
  local above_limit=$((system_limit / 2 + 5))

  # Build command strings
  for i in $(seq 1 $above_limit); do
    cats_above="${cats_above} cat"
  done

  exec="${TIMEOUT_FULL} ./${NAME} Makefile"
  cmd="$exec ${cats_above} ${out1}"
  output=$($cmd 2>&1)
  exit=$?

  if [ -z "$output" ] && diff "Makefile" "${out1}" >/dev/null && [ $exit -eq 0 ]; then
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  elif [ $exit -eq 139 ]; then
    printf "${YB}$title:${RC} ${RB}KO${RC} - Segmentation fault (SIGSEGV) (core dumped)\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    # If output is not empty or exit code is not 0, presume graceful handling
    printf "${YB}$title:${RC} ${RB}KO${RC} - Error printed | Exit code: $exit\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_arguments_count() {
  local title="Arguments count"
  local reason="Program should run with at least 5 arguments"

  exec="$TIMEOUT_FULL ./$NAME"
  stdout=$($exec "${in1}" "echo 4" "echo 2" "${out1}" 2>/dev/null)

  # Check if anything was captured from stdout
  if [ -z "$stdout" ]; then
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${YB}$title:${RC} ${RB}KO${RC} - $reason\n"
    printf "${BB}$title:${RC} ${YB}Eg${RC} - ./pipex here_doc EOF cat outf\n"
    printf "\n${CB}INFO:${RC} Bonus ${YB}<extra>${RC} tests aborted!\n\n"
    exit 1
  fi
}

test_zombie_processes() {
  local title="Zombie processes"
  local zombie_prog="zombie_test"

  cat >${zombie_prog}.c <<'EOF'
#include <sys/types.h>
#include <sys/wait.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <time.h>

int main (int argc, char **argv)
{
  time_t start_time, end_time;
  char *args[10];
  char cmd[100];
  int zombies=0;
  int i;

  args[0] = "./pipex";
  for (i = 1; i < argc && i < 9; i++) {
    args[i] = argv[i];
  }
  args[i] = NULL;

  time(&start_time);
  pid_t pid = fork ();
  if (pid < 0) {
    exit(-1);
  } else if (!pid) {
    execv("./pipex", args);
    exit(-1);
  }
  else {
    usleep(150000);

    sprintf(cmd, "ps --ppid %d -o stat= | grep -c Z", pid);
    FILE *fp = popen(cmd, "r");
    if (fp) {
      char result[10] = {0};
      if (fgets(result, sizeof(result), fp) != NULL) {
          zombies = atoi(result);
      }
      pclose(fp);
    }

    waitpid(pid, NULL, 0);
    time(&end_time);

    printf("%d:%ld", zombies, (long)(end_time - start_time));
    return zombies > 0 ? 1 : 0;
  }
}
EOF

  if ! gcc -o "$zombie_prog" "${zombie_prog}.c" 2>/dev/null; then
    printf "${BB}$title:${RC} ${YB}Skipped${RC} - couldn't compile test program\n"
    rm -rf "${zombie_prog}.c"
    return
  fi

  result=$("./$zombie_prog" "${in1}" "sleep 1" "sleep 0.05" "sleep 1" "${out1}" 2>/dev/null)
  exit_code1=$?
  zombie_count1=$(echo "$result" | cut -d':' -f1)
  duration1=$(echo "$result" | cut -d':' -f2)

  result=$("./$zombie_prog" "${in1}" "sleep 0.05" "sleep 1" "${out1}" 2>/dev/null)
  exit_code2=$?
  zombie_count2=$(echo "$result" | cut -d':' -f1)
  duration2=$(echo "$result" | cut -d':' -f2)

  rm "${zombie_prog}.c" "$zombie_prog"

  if [ "$exit_code1" -eq -1 ] || [ "$exit_code2" -eq -1 ]; then
    printf "${BB}$title:${RC} ${YB}KO${RC} - test execution failed\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  elif [ "$zombie_count1" -gt 0 ] || [ "$zombie_count2" -gt 0 ]; then
    printf "${YB}$title:${RC} ${RB}KO${RC} - zombie processes found\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  elif [ "$duration1" -lt 1 ] || [ "$duration2" -lt 1 ]; then
    printf "${YB}$title:${RC} ${RB}KO${RC} - program exits too quickly\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

run_extra_bonus_tests() {
  print_header "EXTRA BONUS TESTS"
  printf "${CB}INFO:${RC} Extra tests do not create log entries\n\n"
  test_arguments_count
  test_heredoc_limiter
  test_heredoc_append
  test_infile_truncate
  test_file_descriptors
  test_zombie_processes
}
