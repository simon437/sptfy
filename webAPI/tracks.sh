#!/bin/bash
# @Author Simon Olfs
# @Date 27.05.2023

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

# Get the track features of the current track
getRecommendationsByCurrentTrack() {
    local response=$(getCurrentlyPlayingObject)
    local id=$(echo $response | jq -r '.item.id')

    local response=$(getPlayingObject $id)
    local name=$(echo $response | jq -r '.name')
    local popularity=$(echo $response | jq -r '.popularity')
    local image=$(echo $response | jq -r '.album.images[2].url')
    local href=$(echo $response | jq -r '.external_urls.spotify')

    local response=$(getTrackAudioFeatures $id)
    local danceability=$(echo $response | jq -r '.danceability')
    local energy=$(echo $response | jq -r '.energy')
    local speechiness=$(echo $response | jq -r '.speechiness')
    local instrumentalness=$(echo $response | jq -r '.instrumentalness')
    local liveness=$(echo $response | jq -r '.liveness')
    local valence=$(echo $response | jq -r '.valence')
    local tempo=$(echo $response | jq -r '.tempo')

    local access_token=$(get_access_token) 
    local endpoint="https://api.spotify.com/v1/recommendations"
    local url="$endpoint?seed_tracks=$id&target_danceability=$danceability&target_energy=$energy&target_speechiness=$speechiness&target_instrumentalness=$instrumentalness&target_liveness=$liveness&target_valence=$valence"
    event_handler INFO $LINENO "[track] Get track recommendations"
    local response=$(curl -s --request GET \
        --url "$url" \
        --header "Authorization: Bearer $access_token")
    echo $response
}

# Save track to favorites
saveTrackToFavorites() {
    if [ $# != 1 ]; then
        event_handler ERROR $LINENO "[player] No id passed" $EXIT_INTERNAL_ERROR
    fi

    access_token=$(get_access_token) 
    endpoint="https://api.spotify.com/v1/me/tracks"
    url="$endpoint?ids=$1"
    event_handler INFO $LINENO "[player] Add to favorites ($1)"
    local response=$(curl -s --request PUT \
        --url "$url" \
        --header "Authorization: Bearer $access_token")
}
