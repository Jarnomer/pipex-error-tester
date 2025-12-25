#!/bin/bash

source "$(dirname "$0")/variables.sh"
source "$(dirname "$0")/utils.sh"

test_parallel_execution() {
  local title="Parallel execution"
  local reason="Second command is waiting for first"

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

test_interrupt_handling() {
  local title="Interrupt handling"
  local reason="Incorrect exit code after being interrupted"

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
  local reason="Incorrect exit code after segfault in second command"
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

test_invalid_infile() {
  local title="Invalid infile"
  local reason="First command ran without valid infile"

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
  local reason="Second command ran without valid outfile"

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

test_outfile_creation() {
  local title="Outfile creation"
  local reason="No outfile found during first command"

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

test_message_consistency() {
  local title="Message Consistency"
  local reason="Error outputs are not consistent"

  # Bash checks executables before forking. If your messages regarding these
  # don't stay consistent, it means your are checking them inside child process.

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

  result=$("./$zombie_prog" "${in1}" "sleep 0.05" "sleep 1" "${out1}" 2>/dev/null)
  exit_code=$?
  zombie_count=$(echo "$result" | cut -d':' -f1)
  duration=$(echo "$result" | cut -d':' -f2)

  rm "${zombie_prog}.c" "$zombie_prog"

  if [ "$exit_code" -eq -1 ]; then
    printf "${BB}$title:${RC} ${YB}KO${RC} - test execution failed\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  elif [ "$zombie_count" -gt 0 ]; then
    printf "${YB}$title:${RC} ${RB}KO${RC} - zombie processes found\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  elif [ "$duration" -lt 1 ]; then
    printf "${YB}$title:${RC} ${RB}KO${RC} - program exits too quickly\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

test_makefile_rules() {
  local title="Makefile rules"

  make all >/dev/null || {
    printf "${YB}$title:${RC} ${RB}KO${RC} - Could not run make all\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return
  }

  ls "${NAME}" &>/dev/null || {
    printf "${YB}$title:${RC} ${RB}KO${RC} - Executable not found after make all\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return
  }

  make clean >/dev/null || {
    printf "${YB}$title:${RC} ${RB}KO${RC} - Could not run make clean\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return
  }

  ls "${NAME}" &>/dev/null || {
    printf "${YB}$title:${RC} ${RB}KO${RC} - Executable not found after make clean\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return
  }

  make fclean >/dev/null || {
    printf "${YB}$title:${RC} ${RB}KO${RC} - Could not run make make fclean\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return
  }

  ls "${NAME}" &>/dev/null && {
    printf "${YB}$title:${RC} ${RB}KO${RC} - Executable found after make fclean\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return
  }

  make re >/dev/null || {
    printf "${YB}$title:${RC} ${RB}KO${RC} - Could not run make re\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return
  }

  ls "${NAME}" &>/dev/null || {
    printf "${YB}$title:${RC} ${RB}KO${RC} - Executable not found after make re\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return
  }

  if [ "$(check_bonus_rule)" -eq 1 ]; then
    make bonus >/dev/null || {
      printf "${YB}Bonus rule:${RC} ${RB}KO${RC} - Could not run make bonus\n"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    }
  fi

  printf "${BB}$title:${RC} ${GB}OK${RC}\n"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_forbidden_functions() {
  local disallowed_funcs=""
  local title="Forbidden functions"
  local allowed_funcs="open close read write malloc free perror strerror \
    access dup dup2 execve exit fork pipe unlink wait waitpid"

  if ! command -v nm >/dev/null 2>&1; then
    printf "${BB}$title:${RC} ${Y}Skipped${RC} - 'nm' command not available\n"
    return
  fi

  # Get undefined symbols (external function calls) from the binary, filter version out
  used_funcs=$(nm -u "${NAME}" | awk '{print $2}' | sed 's/@.*$//' | sort | uniq)

  for func in $used_funcs; do
    # Skip internal C library functions
    if [[ $func == _* ]]; then
      continue
    fi

    if ! echo "$allowed_funcs" | grep -qw "$func"; then
      disallowed_funcs+="$func "
    fi
  done

  if [ -z "$disallowed_funcs" ]; then
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${YB}$title:${RC} ${RB}KO${RC} - $disallowed_funcs\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_norminette_check() {
  local title="Norminette check"

  if ! command -v norminette >/dev/null 2>&1; then
    printf "${BB}$title:${RC} ${Y}Skipped${RC} - 'norminette' not available\n"
    return
  fi

  norminette &>/dev/null
  if [ $? -eq 0 ]; then
    printf "${BB}$title:${RC} ${GB}OK${RC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "${YB}$title:${RC} ${RB}KO${RC}\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

run_extra_tests() {
  print_header "EXTRA TESTS"
  printf "${CB}INFO:${RC} Extra tests do not create log entries\n\n"
  test_norminette_check
  test_forbidden_functions
  test_makefile_rules
  test_parallel_execution
  test_interrupt_handling
  test_segfault_handling
  test_invalid_infile
  test_invalid_outfile
  test_outfile_creation
  test_message_consistency
  test_zombie_processes
}
