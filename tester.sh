#!/bin/bash

source "$(dirname "$0")/variables.sh"
source "$(dirname "$0")/error.sh"
source "$(dirname "$0")/extra.sh"
source "$(dirname "$0")/utils.sh"

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
          printf "${RB}Error:${RC} Argument ${YB}<TEST_ID>${RC} is missing \n"
          exit 1
        fi
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
  run_error_tests
  run_extra_tests
  print_summary
  cleanup
else
  printf "${RB}ERROR: ${RC}${Y}binary <$NAME> not found${RC}\n"
  exit 1
fi
