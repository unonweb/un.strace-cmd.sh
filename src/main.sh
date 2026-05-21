#!/usr/bin/bash

# BOILERPLATE
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")
ESC=$(printf "\e")
BOLD="${ESC}[1m"
RESET="${ESC}[0m"
CLEAR="\e[0m"
RED="${ESC}[31m"
GREEN="${ESC}[32m"
BLUE="${ESC}[34m"
MAGENTA="\e[35m"
GREY="${ESC}[37m"
CYAN="\e[36m"
UNDERLINE="${ESC}[4m"
BLINKINK="\033[5m"

# DEFAULTS
OUT_DIR="/tmp/strace-logs"
CMD=""
FILTER_SYSCALL_SET=""
FILTER_INCLUDE="" 		# Options: home, system, <any-string>
FILTER_STATUS="" 		# Options: all, success, failed
FILTER_EXCLUDE=""      	# Default: no exclusions
ONLY_MATCHING="false"  	# Default: false (search for paths directly)

# STATIC
SYSCALLS_READ="open,openat,stat,access"
SYSCALLS_WRITE="write,open,openat"
SYSCALLS_EXEC="execve,execveat"

# IMPORTS
source "${SCRIPT_DIR}/lib/print_help_exit.sh"
source "${SCRIPT_DIR}/lib/process_log_file.sh"
source "${SCRIPT_DIR}/lib/parse_args.sh"

if [[ ${#} -eq 0 ]]; then
	echo "ERROR: No args!"
	print_help_exit
fi

parse_args "${@}"

# CHECKS
if [[ -z "${NAME}" ]]; then
    echo "Error: Name (-n) is required."
    print_help_exit
fi

if [[ -z "${CMD}" ]]; then
    echo "Error: Command (-c) is required."
    print_help_exit
fi

if [[ -z "${FILTER_SYSCALL_SET}" ]]; then
    echo "Error: You must select one FILTER_SYSCALL_SET (--read, --write, or --exec)."
    print_help_exit
fi

# LOG FILE PATHS
mkdir -p "${OUT_DIR}"

RAW_LOG="${OUT_DIR}/${NAME}"
FINAL_LOG="${OUT_DIR}/${NAME}"
SORTED_LOG="${OUT_DIR}/${NAME}"

if [[ -n ${FILTER_STATUS} ]]; then
	RAW_LOG+="-${FILTER_STATUS}"
	FINAL_LOG+="-${FILTER_STATUS}"
	SORTED_LOG+="-${FILTER_STATUS}"
fi

RAW_LOG+="-${FILTER_SYSCALL_SET}"
FINAL_LOG+="-${FILTER_SYSCALL_SET}"
SORTED_LOG+="-${FILTER_SYSCALL_SET}"

case "${FILTER_INCLUDE}" in
	"home")
		FINAL_LOG+="-home"
		SORTED_LOG+="-home"
		;;
	"system")
		FINAL_LOG+="-system"
		SORTED_LOG+="-system"
esac

RAW_LOG+=".raw.log"
FINAL_LOG+=".log"
SORTED_LOG+=".sorted.log"

STRACE_ARGS=()
if [[ "${FILTER_STATUS}" == "success" ]]; then
    STRACE_ARGS+=("--status=successful")
elif [[ "${FILTER_STATUS}" == "failed" ]]; then
    STRACE_ARGS+=("--status=failed")
fi

# Intercept Ctrl+C (SIGINT) and termination (SIGTERM)
trap process_log_file SIGINT SIGTERM

echo "Tracing '${CMD}' using system calls: ${SYSCALLS}"
echo "Path filter: ${FILTER_INCLUDE} | Syscall status: ${FILTER_STATUS}"
[[ -n "${FILTER_EXCLUDE}" ]] && echo "Excluding paths containing: ${FILTER_EXCLUDE}"
echo "Press Ctrl+C when you are done tracking the app to safely generate reports."
echo "------------------------------------------------------------------------"

# Execute strace using its native log output to bypass pipe blocks
echo "Running ..."
echo "strace --follow-forks --trace="${SYSCALLS}" "${STRACE_ARGS[@]}" --output "${RAW_LOG}" -- ${CMD}"
echo

strace --follow-forks \
   --trace="${SYSCALLS}" \
   "${STRACE_ARGS[@]}" \
   --output "${RAW_LOG}" \
   -- ${CMD}

# If the target application exits normally on its own, run processing anyway
process_log_file