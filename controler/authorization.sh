#!/bin/bash
# @Author Simon Olfs
# @Date 24.05.2023

# Gets the access token from the config or start the 
# OAuth 2.0 authorization code flow
# @return A valid access token
get_access_token() {
    local access_token=$(grep '^AccessToken' "$config" | cut -d' ' -f2)
    local expire_time=$(grep '^ExpireTime' "$config" | cut -d' ' -f2)

    # Check if authorization code flow is necessary
    if [ "$access_token" == "AccessToken" ]; then
        status=$(authorizationCodeFlow)
        if [ $status -eq 0 ]; then
            access_token=$(grep '^AccessToken' "$config" | cut -d' ' -f2)
        else
            event_handler ERROR $LINENO "OAuth 2.0: Authorization code flow failed" $status
        fi
    fi

    # Check if access token is expired
    if [ $(date "+%s") -gt $expire_time ]; then
        status=$(refresh_token)
        if [ $status -eq 0 ]; then
            access_token=$(grep '^AccessToken' "$config" | cut -d' ' -f2)
        else
            event_handler ERROR $LINENO "OAuth 2.0: Refreshing access token failed" $status
        fi
    fi
    echo $access_token
}

# Implements the OAuth 2.0 authorization code flow
# @return 0 if successful, otherwise errorcode > 0
authorizationCodeFlow() {
    if [[ ! -f $config ]]; then 
        event_handler ERROR $LINENO "configuration file does not exist" $EXIT_GENERAL_ERROR
    fi
    local auth_url token_url redirect_uri port client_id client_secret scope response_type final_url
    auth_url=$(grep '^AuthURL' "$config" | cut -d' ' -f2)
    token_url=$(grep '^TokenURL' "$config" | cut -d' ' -f2)
    redirect_uri=$(grep '^RedirectUri' "$config" | cut -d' ' -f2)
    port=$(echo $redirect_uri | grep -E -o "[0-9]{4}")
    client_id=$(grep '^ClientId' "$config" | cut -d' ' -f2)
    client_secret=$(grep '^ClientSecret' "$config" | cut -d' ' -f2)
    scope=$(grep '^Scope' "$config" |  sed 's/Scope //' | sed 's/ /%20/g')
    response_type=$(grep '^ResponseType' "$config" | cut -d' ' -f2)
    final_url="$auth_url?client_id=$client_id&redirect_uri=$redirect_uri&scope=$scope&response_type=$response_type"

    local response code
    brave-browser-nightly --incognito --chrome-script $final_url 1>/dev/null &
    response=$({ echo -e "HTTP/1.1 200 OK\r\n$(date)\r\n\r\n";echo "<h1>Close the browser</h1>"; } | netcat -l -p $port)
    code=$(echo "$response" | grep GET | cut -d' ' -f 2 | cut -d'=' -f 2)
    sed -E -i "s/^Code.*/Code $code/" $config
    
    response=$(curl -s $token_url --http1.1 \
    --header "Content-Type:application/x-www-form-urlencoded" \
    --header "Authorization: Basic $(echo -n $client_id:$client_secret | base64 -w0)" \
    --data-urlencode "code=$code" \
    --data-urlencode "redirect_uri=$redirect_uri" \
    --data-urlencode "grant_type=authorization_code")

    local expire_time access_token refresh_toekn
    expire_time=$(date -d "+$(echo $response | jq -r '.expires_in') seconds" "+%s")
    sed -E -i "s/^ExpireTime.*/ExpireTime $expire_time/" $config

    access_token=$(echo $response | jq -r '.access_token')
    sed -E -i "s/^AccessToken.*/AccessToken $access_token/" $config

    refresh_token=$(echo $response | jq -r '.refresh_token')
    sed -E -i "s/^RefreshToken.*/RefreshToken $refresh_token/" $config
    
    event_handler INFO $LINENO "OAuth2.0, authorizationCodeFlow access granted"
    echo 0
}

# Refresh the access token
refresh_token() {
    local token_url client_id client_secret refresh_token response
    token_url=$(grep '^TokenURL' "$config" | cut -d' ' -f2)
    client_id=$(grep '^ClientId' "$config" | cut -d' ' -f2)
    client_secret=$(grep '^ClientSecret' "$config" | cut -d' ' -f2)
    refresh_token=$(grep '^RefreshToken' "$config" | cut -d' ' -f2)

    response=$(curl -s $token_url --http1.1 \
    --header "Content-Type:application/x-www-form-urlencoded" \
    --header "Authorization: Basic $(echo -n $client_id:$client_secret | base64 -w0)" \
    --data-urlencode "grant_type=refresh_token" \
    --data-urlencode "refresh_token=$refresh_token")

    local expire_time access_token
    expire_time=$(date -d "+$(echo $response | jq -r '.expires_in') seconds" "+%s")
    sed -E -i "s/^ExpireTime.*/ExpireTime $expire_time/" $config

    access_token=$(echo $response | jq -r '.access_token')
    sed -E -i "s/^AccessToken.*/AccessToken $access_token/" $config

    event_handler INFO $LINENO "Access token refreshed"
    echo 0
}

