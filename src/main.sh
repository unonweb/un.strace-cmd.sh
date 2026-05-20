#!/usr/bin/bash

# Default values
OUT_DIR="/tmp/strace-logs"
CMD=""
FILTER_SYSCALL_SET=""
FILTER_INCLUDE="home" # Options: home, system, none
FILTER_STATUS="all" # Options: all, success, failed
FILTER_EXCLUDE=""      # Default: no exclusions
ONLY_MATCHING="false"  # Default: false (search for paths directly)

# Define system call groups
SYSCALLS_READ="open,openat,stat,access"
SYSCALLS_WRITE="write,open,openat"
SYSCALLS_EXEC="execve,execveat"

# Usage instructions
function usage {
	echo "Usage: $0 -c <cmd_name_or_path> [ --read | --write | --exec | --all ] [ -f <home|system|none> ] [ -s <all|success|failed> ] [ -x <string> ]"
    echo "  -c : Command name or full path to execute"
    echo "  -r : Trace read operations (${SYSCALLS_READ})"
    echo "  -w : Trace write operations (${SYSCALLS_WRITE})"
    echo "  -e : Trace process execution (${SYSCALLS_EXEC})"
	echo "  -a : Trace all syscalls"
    echo "  -f : Filter output paths (Default: home)"
    echo "         home   -> Only paths starting with /home"
    echo "         system -> System paths (e.g., /usr, /etc, etc.)"
    echo "         none   -> All absolute paths"
    echo "  -s : Filter by syscall return status (Default: all)"
    echo "         all     -> Log everything"
    echo "         success -> Only successfully completed calls"
    echo "         failed  -> Only calls returning errors"
    echo "  -x : Exclude lines containing this specific string/substring (case-insensitive)"
    exit 1
}

# Parse flags manually to support clean semantic choices

if [[ ${#} -eq 0 ]]; then
	usage
fi

while [[ ${#} -gt 0 ]]; do
    case "${1}" in
        -c|--cmd)
            CMD="${2}"
            shift 2
            ;;
        --read|-r)
            FILTER_SYSCALL_SET="read"
            SYSCALLS="${SYSCALLS_READ}"
            shift
            ;;
        --write|-w)
            FILTER_SYSCALL_SET="write"
            SYSCALLS="${SYSCALLS_WRITE}"
            shift
            ;;
        --exec|-e)
            FILTER_SYSCALL_SET="exec"
            SYSCALLS="${SYSCALLS_EXEC}"
            shift
            ;;
		--all|-a)
			FILTER_SYSCALL_SET="all"
            SYSCALLS="${SYSCALLS_WRITE},${SYSCALLS_READ},${SYSCALLS_EXEC}"
            shift
			;;
		-i|--include) 
            if [[ "${2}" =~ ^(home|system|none)$ ]]; then
                FILTER_INCLUDE="${2}"
            else
                echo "Error: Invalid filter option '${2}'."
                usage
            fi
            shift 2
            ;;
		-x|--exclude)
            FILTER_EXCLUDE="${2}"
            shift 2
            ;;
		-s|--status)
            if [[ "${2}" =~ ^(all|success|failed)$ ]]; then
                FILTER_STATUS="${2}"
            else
                echo "Error: Invalid status option '${2}'."
                usage
            fi
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

# Validation checks
if [[ -z "${CMD}" ]]; then
    echo "Error: Command (-c) is required."
    usage
fi

if [[ -z "${FILTER_SYSCALL_SET}" ]]; then
    echo "Error: You must select one FILTER_SYSCALL_SET (--read, --write, or --exec)."
    usage
fi

# Ensure output directory exists
mkdir -p "${OUT_DIR}"

# Isolate the clean command name if a full path was provided
CMD_NAME=$(basename "${CMD}")
RAW_LOG="${OUT_DIR}/${CMD_NAME}-${FILTER_SYSCALL_SET}.raw.log"
FINAL_LOG="${OUT_DIR}/${CMD_NAME}-${FILTER_STATUS}-${FILTER_SYSCALL_SET}-${FILTER_INCLUDE}.log"
SORTED_LOG="${OUT_DIR}/${CMD_NAME}-${FILTER_STATUS}-${FILTER_SYSCALL_SET}-${FILTER_INCLUDE}.sorted.log"

function post_processing {
    # Remove the trap immediately so a second Ctrl+C actually kills the script
    trap - SIGINT SIGTERM
    
    echo -e "\n\n[!] Stopping trace. Parsing logs using filter: [${FILTER_INCLUDE}]..."
	echo
    if [[ ! -f "${RAW_LOG}" || ! -s "${RAW_LOG}" ]]; then
        echo "Error: No trace data was captured in ${RAW_LOG}."
        exit 1
    fi

	# INCLUDE
	case "${FILTER_INCLUDE}" in
        home)
            LINE_PATTERN="/home[^]\t\n, )]+"
            EXTRACT_PATTERN='"(/home[^"]+)"'
            ;;
        system)
            LINE_PATTERN="(/usr|/etc|/var|/lib|/lib64|/bin|/sbin|/opt|/sys|/proc|/dev)[^]\t\n, )]+"
            EXTRACT_PATTERN='"((/usr|/etc|/var|/lib|/lib64|/bin|/sbin|/opt|/sys|/proc|/dev)[^"]+)"'
            ;;
        none)
            LINE_PATTERN="/[^]\t\n, )]+"
            EXTRACT_PATTERN='"(/[^"]+)"'
            ;;
    esac

	# HEAD SECTION
	local header=""
	header+="CMD: ${CMD}\n"
	header+="STATUS: ${FILTER_STATUS}\n"
	header+="INCLUDED: "${INCLUDE_PATTERN}"\n"
	[[ -n "${FILTER_EXCLUDE}" ]] && header+="EXCLUDED:  \"${FILTER_EXCLUDE}\"\n"
	header+="--------------\n"
	
	# EXCLUDE & WRITE FINAL_LOG
    if [[ -n "${FILTER_EXCLUDE}" ]]; then
        grep -iv "${FILTER_EXCLUDE}" "${RAW_LOG}" | grep --perl-regexp "${LINE_PATTERN}" > "${FINAL_LOG}"
    else
        grep --perl-regexp "${LINE_PATTERN}" "${RAW_LOG}" > "${FINAL_LOG}"
    fi

	# EXTRACT PATHS & WRITE SORTED_LOG
	if [[ -s "${FINAL_LOG}" ]]; then
		# Parse out just the quoted paths from our newly created log, strip quotes, and sort them
        grep --only-matching --perl-regexp "${EXTRACT_PATTERN}" "${FINAL_LOG}" | tr -d '"' | sort -u > "${SORTED_LOG}"
        
        # Prepend respective headers to both files safely
        echo -e "${header}$(cat "${FINAL_LOG}")" > "${FINAL_LOG}"
        echo -e "${header}$(cat "${SORTED_LOG}")" > "${SORTED_LOG}"
		
		# Feedback
        echo "Unfiltered raw output:   ${RAW_LOG}"
        echo "Entire matched lines:    ${FINAL_LOG}"
        echo "Extracted unique paths:  ${SORTED_LOG}"
    else
		echo "Finished parsing, but no matching paths survived the filters."    
	fi

    return 0
}

STRACE_ARGS=()
if [[ "${FILTER_STATUS}" == "success" ]]; then
    STRACE_ARGS+=("--status=successful")
elif [[ "${FILTER_STATUS}" == "failed" ]]; then
    STRACE_ARGS+=("--status=failed")
fi

# Intercept Ctrl+C (SIGINT) and termination (SIGTERM)
trap post_processing SIGINT SIGTERM

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
post_processing