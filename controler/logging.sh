#!/bin/bash
# @Author Simon Olfs
# @Date 24.05.2023

# Handles events and logs them
#
# @param $1 TYPE The type of the event: INFO, WARNING, ERROR, USAGE
# @param $2 LINE Line where the event occured
# @param $3 MSG The message of the event
# @param $4 ERROR_CODE Optional parameter for the errorcode to exit with
event_handler() {                           
    # check for http error response events
    if [ $# -eq 1 ]; then
        local response=$(cat -)
        if [ -n "$response" ]; then                                                                                                                            
            local message=$(echo $response | jq '.error.message')
            local status_code=$(echo $response | jq '.error.status')
            event_handler ERROR $1 "$message" $status_code
        fi     
        return
    fi

    local TYPE="$1" LINE="$2" MSG="$3" ERROR_CODE=""
    if [ $# -eq 4 ]; then # only error events have an error code
        local ERROR_CODE="$4"
    fi

    case $TYPE in 
        INFO) write_log_entry info "$MSG; Line $LINE" ;;
        WARNING)                    # Print warning to stderr, but do not abort.
            echo -e >&2 "\x1b[43m\x1b[30m Warning \x1b[0m $MSG"
            write_log_entry warning "$MSG; Line: $LINE" ;;
        ERROR)                      # Print error message and abort with error code.
            echo -e >&2 "\x1b[41m\x1b[30m Error \x1b[0m $MSG"
            write_log_entry err "$MSG; Line: $LINE; Code: $ERROR_CODE"
            exit $ERROR_CODE ;;
        USAGE)                      # Print help info and log error
            echo >&2 "Use option -h for help."
            event_handler ERROR $LINE "$MSG" $EXIT_USAGE ;;
        *) ;;
    esac
} 

# Write an log entry to journal log
# $1 Type of entry, $2 Message to write
write_log_entry() {
    logger -p $1 "${PROGNAME}[$1]: $2"                                                                                                                                                                                                        
}

