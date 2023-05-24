#!/bin/bash
# @Author Simon Olfs
# @Date 24.05.2023

# Initialize devices
# @return Status 0 if a device was activated otherwise 1
initializeDevice() {
    local active_devices=$(getActiveDevices);
    if [ "$active_devices" == 1 ]; then # no active device found
        
        # start and activate spotifyd depending on the config
        initializeSpotifyd

        # activate the default device or first available
        local default_device=$(grep '^Device ' "$config" | cut -d' ' -f2)
        if [ -n "$default_device" ] && [ "$default_device" != "Device" ]; then
            local status=$(activateDevice $default_device)
            if [ $status == 1 ]; then # failed to activate default device
                local available_devices=$(getAvailableDevices)
                first_available_device=$(echo $available_devices | jq -r ".devices[0].id")
                status=$(activateDevice $first_available_device)
                if [ $status == 1 ]; then # failed to activate first available device
                    echo 1; return
                fi
            fi
        fi
    fi
    echo 0; return
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

    echo 0
}

# Check if spotifyd should be startet. Can be set in the configuration file
initializeSpotifyd() {
    local spotifyd=$(grep '^spotifyd' "$config" | cut -d' ' -f2)
    if [ "$spotifyd" == "true" ]; then
        if [ ! $(pgrep "spotifyd") ]; then
            spotifyd &
        fi
    fi
    if [ ! $(pgrep "spotifyd") ]; then
        event_handler WARNING $LINENO "[devices] Failed to start spotifyd"
    fi
}

# Get the active devices
# @return JSON-Formattet active devices or 1 when no devices are active
getActiveDevices() {
    local available_devices=$(getAvailableDevices)
    if [ "$available_devices" == 1 ]; then
            event_handler WARNING $LINENO "[devices] No Active device found"
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
            fi
        done
        if [ "$active_devices" == '{ "devices" : [ ] }' ]; then
            echo 1; return
        fi
        echo $active_devices 
    fi
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
        event_handler ERROR $LINENO "No active devices" $EXIT_GENERAL_ERROR
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
        return
    fi
}
