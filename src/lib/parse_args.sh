function parse_args {
	
	source "${SCRIPT_DIR}/lib/print_help_exit.sh"
	
	while [[ ${#} -gt 0 ]]; do
		case "${1}" in
			-n|--name)
				NAME="${2}"
				shift 2
				;;
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
					print_help_exit
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
					print_help_exit
				fi
				shift 2
				;;
			*)
				echo "ERROR: Unknown flag: ${1}"
				print_help_exit
				;;
		esac
	done
}