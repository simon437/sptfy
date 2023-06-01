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
    if [ $# != 1 ] && [ $# != 2 ]; then
        event_handler ERROR $LINENO "No uri passed" $EXIT_INTERNAL_ERROR
    fi

    access_token=$(get_access_token) 
    endpoint="https://api.spotify.com/v1/me/player/play"
    url="$endpoint?&access_token=$access_token"
    if [ $# == 1 ]; then
        event_handler INFO $LINENO "[play] $endpoint; URI: $1"
        curl -s --location --request PUT $url \
        --header 'Content-Type: application/json' \
        --data "{
            \"context_uri\": \"$1\",
            \"position_ms\": 0
        }" | event_handler $LINENO
    else
        event_handler INFO $LINENO "[play] $endpoint; URI: $1"
        curl -s --location --request PUT $endpoint \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer $access_token" \
        --data "{
            \"context_uri\": \"$1\",
            \"offset\": {
                \"position\": $2
            }
        }" | event_handler $LINENO
    fi
}

# Skips to next track in the user's queue
skipToNext() {
    access_token=$(get_access_token) 
    local endpoint="https://api.spotify.com/v1/me/player/next"
    event_handler INFO $LINENO "[player] Skip to next"
    curl -s --request POST \
        --url $endpoint \
        --header "Authorization: Bearer $access_token" | 
        event_handler $LINENO
} 

# Skips to previous track in user's queue
skipToPrev() {
    access_token=$(get_access_token) 
    local endpoint="https://api.spotify.com/v1/me/player/previous"
    event_handler INFO $LINENO "[player] Skip to previous"
    curl -s --request POST \
        --url $endpoint \
        --header "Authorization: Bearer $access_token" | 
        event_handler $LINENO
}

# Set the volume for the current playback device
setPlaybackVolume() {
    local active_device=$(getActiveDevice)
    local current_volume=$(echo $active_device | jq -r '.[].volume_percent')
    local new_volume=$(changeVol $1 $current_volume)
    local access_token=$(get_access_token) 
    local endpoint="https://api.spotify.com/v1/me/player/volume"
    local url="$endpoint?volume_percent=$new_volume"
    event_handler INFO $LINENO "[player] Set volume to $new_volume"
    curl -s --request PUT \
        --url $url \
        --header "Authorization: Bearer $access_token" | 
        event_handler $LINENO
}

# change volume
# @param $1 + For increase the volume
# @param $1 - For decreasing the volume
# @return volume
changeVol() {
    local step=10
    local volume=0
    if [ "$1" == "up" ]; then
        volume=$(($2+$step))
    elif [ "$1" == "down" ]; then
        volume=$(($2-$step))
    fi
    if [ $volume -gt 100 ]; then
        volume=100
    elif [ $volume -lt 0 ]; then
        volume=0
    fi
    echo $volume
}

# Get the object currently being played
getCurrentlyPlayingObject() {
    access_token=$(get_access_token) 
    endpoint="https://api.spotify.com/v1/me/player/currently-playing"
    event_handler INFO $LINENO "[player] Get currently playing track"
    local response=$(curl -s --request GET \
        --url "$endpoint" \
        --header "Authorization: Bearer $access_token")
    echo $response
}


# Get information for a single track
getPlayingObject() {
    if [ $# != 1 ]; then
        event_handler ERROR $LINENO "[player] No id passed" $EXIT_INTERNAL_ERROR
    fi

    access_token=$(get_access_token) 
    endpoint="https://api.spotify.com/v1/tracks/$1"
    event_handler INFO $LINENO "[player] Get track by id ($1)"
    local response=$(curl -s --request GET \
        --url "$endpoint" \
        --header "Authorization: Bearer $access_token")
    echo $response
}

# Get audio feature information by ID
getTrackAudioFeatures() {
    if [ $# != 1 ]; then
        event_handler ERROR $LINENO "[player] No id passed" $EXIT_INTERNAL_ERROR
    fi

    access_token=$(get_access_token) 
    endpoint="https://api.spotify.com/v1/audio-features/$1"
    event_handler INFO $LINENO "[player] Get track features by id ($1)"
    local response=$(curl -s --request GET \
        --url "$endpoint" \
        --header "Authorization: Bearer $access_token")
    echo $response
}

# Add track to queue
addToQueue() {
    if [ $# != 1 ]; then
        event_handler ERROR $LINENO "[player] No id passed" $EXIT_INTERNAL_ERROR
    fi
    access_token=$(get_access_token) 
    endpoint="https://api.spotify.com/v1/me/player/queue"
    url="$endpoint?uri=$1"
    event_handler INFO $LINENO "[player] Put track to queue($1)"
    local response=$(curl -s --request POST \
        --url "$url" \
        --header "Authorization: Bearer $access_token")
}
