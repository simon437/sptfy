#!/bin/bash
# @Author Simon Olfs
# @Date 24.05.2023

# Initialize devices
# @return Status 0 if a device was activated otherwise 1
initializeDevice() {
    local active_devices=$(getActiveDevice);
    if [ "$active_devices" == 1 ]; then # no active device found
        
        # start and activate spotifyd depending on the config
        initializeSpotifyd
        

        local default_device=$(grep '^Device ' "$config" | cut -d' ' -f2)
        if [ -n "$default_device" ]; then # activate the default device
            local status=$(activateDevice $default_device)
        else # activate first device
            local available_devices=$(getAvailableDevices)
            if [ "$available_devices" != 1 ]; then
                local first_available_device=$(echo $available_devices | jq -r ".devices[0].id")
                status=$(activateDevice $first_available_device)
                
                if [ $status == 1 ]; then # failed to activate first available device
                    echo 1; return
                fi
            fi
            # no devices available
        fi

    fi
    echo 0; return
}

# Check if spotifyd should be startet. Can be set in the configuration file
initializeSpotifyd() {
    local spotifyd=$(grep '^spotifyd' "$config" | cut -d' ' -f2)
    if [ "$spotifyd" == "true" ]; then
        if [ -z "$(pgrep spotifyd)" ]; then
            spotifyd &
            sleep 5 # the system needs a short time to start the process
                    # Better solution would be to active wait for the process!
        elif [ -z "$(pgrep spotifyd)" ]; then
            event_handler WARNING $LINENO "[devices] Failed to start spotifyd"
        fi
    fi
}

# Activates a device
# @param device_id The id of the device to activate
# @return Status 0 if successful or 1 if not
activateDevice() {
    if [ $# != 1 ]; then                # validate the parameter
        echo 1; return
    fi

    local access_token=$(get_access_token) 
    local device_id=$1

    curl -s --location --request PUT 'https://api.spotify.com/v1/me/player' \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer $access_token" \
    --data "{
        \"device_ids\": [
            \"$device_id\"
        ]
    }" | event_handler $LINENO
    event_handler INFO $LINENO "[devices] Activated device; ID:$device_id)"

    sleep 5 # the web-api needs a short time to activate a device. A bettwer
            # solution would be to active wait here until the device is active.
    echo 0
}

# Get the active devices
# @return JSON-Formattet active devices or 1 when no devices are active
getActiveDevice() {
    local available_devices=$(getAvailableDevices)
    if [ "$available_devices" == 1 ]; then
            event_handler INFO $LINENO "[devices] No Active device found"
            echo 1; return
    else
        local active_devices='{ "devices" : [ ] }'
        local number_of_devices=$(echo $available_devices | jq '.devices | length')
        if [ -z $number_of_devices ]; then
            echo 1; return
        fi
        for (( i=0; i < "$number_of_devices" ; i++ )); do 
            local device=$(echo $available_devices | jq ".devices[$i]")
            local is_active=$(echo $device | jq -r ".is_active")
            if [ "$is_active" == "true" ]; then
                active_devices=$(echo $active_devices | jq ".devices + [$device]")
                echo $active_devices 
                return;
            fi
        done
    fi
    echo 1; return
}

# Get information about a user's available devices
# @return JSON-Formattet response of devices or in case of an error the error-code
getAvailableDevices() {
    local access_token=$(get_access_token) 
    local response=$(curl -s --request GET \
        --url "https://api.spotify.com/v1/me/player/devices" \
        --header "Authorization: Bearer $access_token")
    local devices=$(echo $response | jq '.devices | length')
    event_handler INFO $LINENO "[devices] Available devices: $devices"
    if [ "$devices" == "0" ]; then
        event_handler INFO $LINENO "[devices] No available devices"
        echo 1; return
    fi
    echo $response
}

# Shows the available devices as list. The default device is marked blue
listDevices() {
    if [ -n "$opt_d_val" ] && [ "$opt_d_val" != "select" ]; then 
        event_handler USAGE $LINENO "Invalid option $opt_d_val"
    fi

    local access_token=$(get_access_token) 
    local response=$(curl -s --request GET \
        --url "https://api.spotify.com/v1/me/player/devices" \
        --header "Authorization: Bearer $access_token")
    local devices=$(echo $response | jq '.devices | length')
    if [ "$devices" == "0" ]; then
        event_handler WARNING $LINENO "No active devices"
        return
    fi

    local device id is_active name type volume default_device
    printf "%-5s%-42s%-10s%-25s%-13s%-10s\n" "#" "ID" "ACTIVE" "NAME" "TYPE" "VOLUME"
    for (( i=0; i < $devices ; i++ ))
    do
        device=$(echo $response | jq -r ".devices[$i]")
        id=$(echo $device | jq -r ".id")
        is_active=$(echo $device | jq -r ".is_active")
        name=$(echo $device | jq -r ".name")
        type=$(echo $device | jq -r ".type")
        volume=$(echo $device | jq -r ".volume_percent")
        default_device=$(grep '^Device' "$config" | cut -d' ' -f2)
        if [ "$default_device" == "$id" ]; then
            printf "\x1b[34m%-5s%-42s%-10s%-25s%-13s%-10s\x1b[0m\n" \
                "$(($i+1))" "$id" "$is_active" "$name" "$type" "$volume"
        else
            printf "%-5s%-42s%-10s%-25s%-13s%-10s\n" \
                "$(($i+1))" "$id" "$is_active" "$name" "$type" "$volume"
        fi
    done

    if [ -n "$opt_d_val" ]; then 
        if [ "$opt_d_val" != "select" ]; then 
            event_handler USAGE $LINENO "Invalid option $opt_d_val"
        fi

        read -p "Select a new default device: " id
        id=$(echo $response | jq -r ".devices[$(($id-1))].id")
        sed -E -i "s/^Device.*/Device $id/" $config
        local status=$(activateDevice $default_device)
        return
    fi
}

# Display the current track as notification
displayCurrentPlay() {
    if [ $# != 1 ]; then
        event_handler ERROR $LINENO "No summary provided" $EXIT_INTERNAL_ERROR
    fi
    local output=""
    local response=$(getCurrentlyPlayingObject)
    local id=$(echo $response | jq -r '.item.id')
    local track=$(echo $response | jq -r '.item.name')
    local track_url=$(echo $response | jq -r '.item.external_urls.spotify')
    output+=`printf "%-10s<a href=\"%s\">%s</a>" "Track:" "$track_url" "$track"`

    local artists=""
    local length=$(echo $response | jq '.item.artists | length')
    for (( i=0; i < $length ; i++ )); do
        local artist=$(echo $response | jq -r ".item.artists[$i].name")
        local artist_url=$(echo $response | jq -r ".item.artists[$i].external_urls.spotify")
        output+=`printf "\n%-10s<a href=\"%s\">%s</a>" "Artist:" "$artist_url" "$artist"`
    done

    local notification_conf=$(grep '^displayInformation' "$config")
    if [ -n "$notification_conf" ]; then
        local image=$(echo $response | jq -r '.item.album.images[2].url')
        local tmp=$(mktemp)
        wget --quiet -O $tmp $image
        notify-send --urgency=low -i $tmp --app-name "$PROGNAME" \
        "$1" \
        "$output"
        rm -rf $tmp
    else
        echo -e "$output"
    fi
}



# Get the track features of the current track
# param $1 The id of a specific track. If no parameter is passed the current
#          track is taken
getTrackFeatures() {
    if [ $# != 1 ]; then
        local response=$(getCurrentlyPlayingObject)
        local id=$(echo $response | jq -r '.item.id')
    else
        local id=$1
    fi

    local response=$(getPlayingObject $id)
    local name=$(echo $response | jq -r '.name')
    local artists=""
    local artists_id=""
    local length=$(echo $response | jq '.artists | length')
    for (( i=0; i < $length ; i++ )); do
        local artist_name=$(echo $response | jq -r ".artists[$i].name")
        local artist_id=$(echo $response | jq -r ".artists[$i].id")
        if [ $length -gt 1 -a $i -lt $(($length - 1)) ]; then
            artists+="$artist_name,"
            artists_id+="$artist_id,"
        else
            artists+="$artist_name"
            artists_id+="$artist_id"
        fi
    done

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

    local track="{ \"track\" : { 
        \"track_name\": \"$name\",
        \"artists_name\": \"$artists\",
        \"seed_tracks\": \"$id\", 
        \"seed_artists\": \"$artists_id\",
        \"target_popularity\": \"$popularity\",
        \"target_danceability\": \"$danceability\",
        \"target_energy\": \"$energy\",
        \"target_speechiness\": \"$speechiness\",
        \"target_instrumentalness\": \"$instrumentalness\",
        \"target_liveness\": \"$liveness\",
        \"target_valence\": \"$valence\",
        \"target_tempo\": \"$tempo\",
        \"limit\": \"1\"
    }}"
    echo $track
}

# Display information about a track
displayInfoTrack() {
    if [ $# != 1 ]; then
        local response=$(getCurrentlyPlayingObject)
        local id=$(echo $response | jq -r '.item.id')
    else
        local id=$1
    fi
        
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

    local output=""
    output+=`printf "%-20s<a href=\"%-30s\">%s</a>" "Song:" "$href" "$name"`
    output+=`printf "\n%-20s%-30s\n" "Popularity:" "$popularity"`
    output+=`printf "\n%-20s%-30s" "danceability:" "$danceability"`
    output+=`printf "\n%-20s%-30s" "enery:" "$energy"`
    output+=`printf "\n%-20s%-30s" "speechiness:" "$speechiness"`
    output+=`printf "\n%-20s%-30s" "instrumentalness:" "$instrumentalness"`
    output+=`printf "\n%-20s%-30s" "liveness:" "$liveness"`
    output+=`printf "\n%-20s%-30s" "valence:" "$valence"`
    output+=`printf "\n%-20s%-30s" "tempo:" "$tempo"`

    local notification_conf=$(grep '^displayInformation' "$config")
    if [ -n "$notification_conf" ]; then
        local tmp=$(mktemp)
        wget --quiet -O $tmp $image
        notify-send --urgency=low -i $tmp --app-name "$PROGNAME" "Track details:" \
            "$output"
        rm -rf $tmp
    else
        echo -e "$output"
    fi
}
