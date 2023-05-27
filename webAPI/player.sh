#!/bin/bash
# @Author Simon Olfs
# @Date 24.05.2023

# Pause playback on the user's accounts
pausePlayback() {
    local access_token=$(get_access_token) 
    event_handler INFO $LINENO "[devices] Pause playback"
    curl -s --location --request PUT 'https://api.spotify.com/v1/me/player/pause' \
    --header "Authorization: Bearer $access_token" | event_handler $LINENO
}

# Get information about the user's current playback state
# @return 1 if no devices is playing otherwise 0
getPlaybackState() {
    local access_token=$(get_access_token) 
    local response=$(curl -s --request GET \
        --url "https://api.spotify.com/v1/me/player" \
        --header "Authorization: Bearer $access_token")
    local play_state=$(echo $response | jq '.is_playing')
    if [ "$play_state" == "true" ]; then
        echo 0; return
    fi
    echo 1
}

# Resumes playing on active device
resumePlayback() {
    local access_token=$(get_access_token) 
    local endpoint="https://api.spotify.com/v1/me/player/play"
    event_handler INFO $LINENO "[play] $endpoint; Resume playing on active device"
    curl -s --location --request PUT $endpoint \
        --header "Authorization: Bearer $access_token" | event_handler $LINENO
}

# Start a new context on the active device
# @param uri The spotify URI
startPlayback() {
    if [ $# != 1 ]; then
        event_handler ERROR $LINENO "No uri passed" $EXIT_INTERNAL_ERROR
    fi

    access_token=$(get_access_token) 
    endpoint="https://api.spotify.com/v1/me/player/play"
    url="$endpoint?&access_token=$access_token"
    event_handler INFO $LINENO "[play] $endpoint; URI: $1"
    curl -s --location --request PUT $url \
    --header 'Content-Type: application/json' \
    --data "{
        \"context_uri\": \"$1\",
        \"position_ms\": 0
    }" | event_handler $LINENO
}

# Skips to next track in the user's queue
skipToNext() {
    access_token=$(get_access_token) 
    local endpoint="https://api.spotify.com/v1/me/player/next"
    event_handler INFO $LINENO "[player] Skip to next"
    local response=$(curl -s --request POST \
        --url $endpoint \
        --header "Authorization: Bearer $access_token" | 
        event_handler $LINENO)
}

# Get the object currently being played
getCurrentlyPlayingTrack() {
    access_token=$(get_access_token) 
    endpoint="https://api.spotify.com/v1/me/player/currently-playing"
    event_handler INFO $LINENO "[player] Get currently playing track"
    local response=$(curl -s --request GET \
        --url "$endpoint" \
        --header "Authorization: Bearer $access_token")
    echo $response
}
