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

   -d,                           List available devices
       [select]                  Select a device for playback

   -p, ["Release Radar"],        Start playing the default playlist (default="Release Radar")
       [<name>]                  Play a specified playlist by name. This is a search 
                                 function. So not only the own playlists can be started

   -i, [play],                   Show information about the current play (default=play)
       [song]                    Show detail information about the current song

   -r,                           Get recommendations (default=song)
       [song],                   Recommendations based on the current playing track
       [artist],                 [TODO] Recommendations based on the current playing artist
       [playlist]                [TODO] Recommendations based on the current playing playlist
   
   -n                            Skip to next track in the queue
   -f                            Save current track to favorites

Arguments:
   next                          Skip to next track
   prev                          Skip to previous track
   pause                         Pause playback
   resume                        Resume playback
   up                            Volume up
   down                          Volume down

Examples:
    $PROGNAME                        Resume play on active device
    $PROGNAME -d                     List all active devices
    $PROGNAME -d select              List all active devices an select a default device.
                                     Selecting a default device can used to transfer the
                                     playback to the selected device as well.
    $PROGNAME -p "Discover Weekly"   Play the discover weekly playlist on default device
EOF
}

# Print version information.
version() {
    echo "$PROGNAME $VERSION"
}
