#!/bin/bash
# @Author Simon Olfs
# @Date 27.05.2023

# Get the object currently being played
getCurrentlyPlayingTrack() {
    access_token=$(get_access_token) 
    endpoint="https://api.spotify.com/v1/me/player/currently-playing"

    event_handler INFO $LINENO "[] $endpoint; URI: $1"
    local response=$(curl -s --request GET \
        --url "$endpoint" \
        --header "Authorization: Bearer $access_token")
}
