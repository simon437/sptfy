#!/bin/bash
# @Author Simon Olfs
# @Date 24.05.2023

# Get spotify catalog information
# @param type The item type to search: album, artist, playlist, track, 
#             show, episode, audiobook
# @param query The search query
search() {
    local endpoint query url response uri
    endpoint="https://api.spotify.com/v1/search"
    query=$(echo $2 | sed "s/[[:space:]]/%20/g")
    url="$endpoint?q=$query&type=$1&access_token=$(get_access_token)"
    response=$(curl -s --location $url)
    event_handler INFO $LINENO "[search] $endpoint; Query: q=$query&type=$1"
    uri=$(echo $response | jq -r ".playlists.items[] | select(.name | test(\"$2\")) | .uri")
    echo $uri | cut -d' ' -f1
}


