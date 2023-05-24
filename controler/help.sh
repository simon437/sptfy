#!/bin/bash
# @Author Simon Olfs
# @Date 24.05.2023

# Output help.
usage() {
cat <<-EOF
Usage: $PROGNAME [<OPTIONS>] <arguments>
Controle spotify devices

Options:
   -h                            Print this help
   -v                            Print version number
   -d [select]                   List available devices. Default device is colored
   -p <name>                     Start a playlist by name. Default is Release Radar
   -n                            Skip to next track in the queue

Examples:
    $PROGNAME                        Resume play on active device
    $PROGNAME -d                     List all active devices
    $PROGNAME -d select              List all active devices an select a default device
    $PROGNAME -p "Discover Weekly"   Play the discover weekly playlist on default device
EOF
}

# Print version information.
version() {
    echo "$PROGNAME $VERSION"
}
