function process_log_file {
	# REQUIRES
	# - FILTER_INCLUDE
	# - RAW_LOG
	# - FINAL_LOG
	# - SORTED_LOG

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
            local line_pattern="/home[^]\t\n, )]+"
            local extract_pattern='"(/home[^"]+)"'
            ;;
        system)
            local line_pattern="(/usr|/etc|/var|/lib|/lib64|/bin|/sbin|/opt|/sys|/proc|/dev)[^]\t\n, )]+"
            local extract_pattern='"((/usr|/etc|/var|/lib|/lib64|/bin|/sbin|/opt|/sys|/proc|/dev)[^"]+)"'
            ;;
        none)
            local line_pattern="/[^]\t\n, )]+"
            local extract_pattern='"(/[^"]+)"'
            ;;
    esac

	# HEAD SECTION
	local header=""
	header+="CMD: ${CMD}\n"
	header+="STATUS: ${FILTER_STATUS}\n"
	header+="INCLUDED: "${FILTER_INCLUDE}"\n"
	[[ -n "${FILTER_EXCLUDE}" ]] && header+="EXCLUDED:  \"${FILTER_EXCLUDE}\"\n"
	header+="--------------\n"
	
	# EXCLUDE & WRITE FINAL_LOG
    if [[ -n "${FILTER_EXCLUDE}" ]]; then
        grep -iv "${FILTER_EXCLUDE}" "${RAW_LOG}" | grep --perl-regexp "${line_pattern}" > "${FINAL_LOG}"
    else
        grep --perl-regexp "${line_pattern}" "${RAW_LOG}" > "${FINAL_LOG}"
    fi

	# EXTRACT PATHS & WRITE SORTED_LOG
	if [[ -s "${FINAL_LOG}" ]]; then
		# Parse out just the quoted paths from our newly created log, strip quotes, and sort them
        grep --only-matching --perl-regexp "${extract_pattern}" "${FINAL_LOG}" | tr -d '"' | sort -u > "${SORTED_LOG}"
        
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