function print_help_exit {
	echo "Usage: ${0} -n <name> -c <cmd> [ --read | --write | --exec | --all ] [ -f <home|system|none> ] [ -s <all|success|failed> ] [ -x <string> ]"
	echo "  -n | --name    : Name for the logs"
    echo "  -c | --cmd     : Command or full path to execute"
    echo "  -r | --read    : Trace read operations (${SYSCALLS_READ})"
    echo "  -w | --write   : Trace write operations (${SYSCALLS_WRITE})"
    echo "  -e | --exec    : Trace process execution (${SYSCALLS_EXEC})"
	echo "  -a | --all     : Trace all syscalls"
    echo "  -f | --filter  : Filter output paths (Default: home)"
    echo "         home    -> Only paths starting with /home"
    echo "         system  -> System paths (e.g., /usr, /etc, etc.)"
    echo "         none    -> All absolute paths"
    echo "  -s | --status  : Filter by syscall return status (Default: all)"
    echo "         all     -> Log everything"
    echo "         success -> Only successfully completed calls"
    echo "         failed  -> Only calls returning errors"
    echo "  -x | --exclude : Exclude lines containing this specific string/substring (case-insensitive)"
    exit 1
}