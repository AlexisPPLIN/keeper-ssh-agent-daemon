#!/bin/bash

# 
# Keeper ssh-agent daemon
# Runs ssh-agent as a service and allows for ssh connections without private keys on the host
#
# Author : AlexisPPLIN
#

# ---------------- Variables ----------------

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

CONFIG_FILE=/home/$USER/.keeper/config.json

# ---------------- Helpers functions ----------------

# Checks if keeper ssh-agent socket is opened
function socketIsOpened() {
    SSH_AGENT=`ls /home/$USER/.keeper/*.ssh_agent`;

    SSH_AUTH_SOCK=$SSH_AGENT ssh-add -q -l 2>/dev/null
    if [ $? -ne 0 ]; then
        return 1;
    fi;

    return 0;
}

# Waits for keeper ssh-agent socket to open (or fail if timeout is exceded)
function waitForSocketToOpenOrFail() {
    export -f socketIsOpened
    timeout 10 bash <<TIME
        while ! socketIsOpened; do
            sleep 0.1;
        done
TIME

    if [ $? -ne 0 ]; then
        echo "Timeout of ssh-agent socket"
        exit 1;
    fi;
}

# Use zenity to ask user his keeper credentials
# Then save it into gnome keychain
function askForPassword() {
    FORM=`zenity --forms \
        --add-entry="Email" \
        --add-password="Mot de passe maître" \
        --add-combo="Server" --combo-values="keepersecurity.eu" \
        --title='Keeper ssh-agent' \
        --text=''`

    [[ "$?" != "0" ]] && exit 1

    KEEPER_EMAIL=`echo $FORM | cut -d'|' -f1`
    KEEPER_PW=`echo $FORM | cut -d'|' -f2`
    KEEPER_SERVER=`echo $FORM | cut -d'|' -f3`

    if [ ! -f $CONFIG_FILE ]; then
        expect <<EOD
        set timeout -1
        spawn keeper login

        expect "User(Email): "
        send "$KEEPER_EMAIL\r"

        expect "Type your selection or <Enter> to resume: "
        send "email_send\n"

        expect {
            "Type your selection or <Enter> to resume: " {
                send "\r"
                sleep 1
                exp_continue
            }
            "Password: " {
                send "\n"
            }
        }
EOD
    fi

    tmp=$(mktemp --suffix=keeper)
    jq  --arg user "$KEEPER_EMAIL" \
        --arg pass "$KEEPER_PW" \
        '.user = $user | .password = $pass' \
        $CONFIG_FILE > "$tmp";
    
    mv "$tmp" $CONFIG_FILE;

    storeKeeperConfigFile $CONFIG_FILE
    rm $CONFIG_FILE

    # Check if password is valid
    if ! isLogged; then
        askForPassword
    fi
}

# Store keeper config file into Gnome Keyring
function storeKeeperConfigFile() {
    if [ ! -f $1 ]; then
        return 1
    fi

    content=`cat $1`;
    content=`echo $content | tr -d '\n'`

    if [ -z "$content" ]; then
        return 1
    fi

    json=`echo $content | jq -c`
    echo $json | secret-tool store -l 'keeper' config keeper
}

# Retrieve keeper config file from Gnome Keyring as a temporary file
function getConfigFile() {
    unparsed_json=`secret-tool lookup config keeper`
    if [ $? -ne 0 ]; then
        return 1;
    fi;

    file=$(mktemp --suffix=keeper)
    echo $unparsed_json | jq > $file

    echo $file
    return 0
}

# Checks if user is logged to Keeper
function isLogged() {
    if ! config=`getConfigFile`; then
        return 1
    fi

    test=`timeout 10 keeper --config=$config whoami`
    rm $config;

    if echo $test | grep "User:"; then
        return 0
    fi

    return 1
}

# Checks if screen of Keeper ssh-agent is started
function isScreenStarted() {
    if screen -list | grep -q "keeper-ssh"; then
        return 0
    fi

    return 1
}

# Adds Keeper ssh-agent socket to .bashrc
function addSshAgentSocketToBashrc() {
    SSH_AGENT=`ls /home/$USER/.keeper/*.ssh_agent`;
    SSH_AUTH_SOCK=$SSH_AGENT
    
    echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" >> ~/.bashrc
    return 0
}

# Adds Keeper ssh-agent socket from .bashrc
function removeSshAgentSocketToBashrc() {
    sed -i "/^export SSH_AUTH_SOCK=/d" ~/.bashrc

    # unset it in the environment
    unset SSH_AUTH_SOCK

    return 0
}

# Extract ssh public keys from ssh-agent into ~/.ssh/keeper/ folder
# This is usefull when you use a lot of ssh keys
# You can configure your ~/.ssh/config to use a specific key
#
# Example :
# In Keeper you have a "main-server" ssh key
#
# ~/.ssh/config :
# Host main-server.example.com
#   ForwardAgent yes
#   IdentityFile ~/.ssh/keeper/main-server.pub
#
# Then when you do : ssh user@main-server.example.com
# ssh-agent will only return main-server private key and not loop on others
#
function createSshPublicKeyFilesFromAgent() {
    pubkeys=`ssh-add -L`
    if [ $? -ne 0 ]; then
        return 1;
    fi;

    mkdir -p ~/.ssh/keeper

    regex="ssh-.* (.*)"

    readarray -t rows <<<"$pubkeys"
    for row in "${rows[@]}";do
        if [[ $row =~ $regex ]]
        then
            name="${BASH_REMATCH[1]}";
            echo $row > ~/.ssh/keeper/$name.pub
        else
            echo -e "${RED}[2/5] Error : public key $row does not respect syntax${NC}";
        fi
    done

    return $pubkey
}

# Deletes all public keys from ~/.ssh/keeper/ folder
function deleteSshPublicKeys() {
    rm ~/.ssh/keeper/*.pub
}

# ---------------- Main script ----------------

case $1 in
start)
    echo -e "${YELLOW}[1/5] Checking if current is logged to his vault...${NC}";

    if ! isLogged; then
        askForPassword
    fi

    config=`getConfigFile`;

    echo -e "${YELLOW}[2/5] Checking if ssh-agent is not already running...${NC}";
    if ! isScreenStarted; then
        screen -dm -S keeper-ssh keeper --config=$config ssh-agent start
    fi

    echo -e "${YELLOW}[3/5] Adding SSH_AUTH_SOCK to bashrc...${NC}";
    addSshAgentSocketToBashrc

    echo -e "${YELLOW}[4/5] Waiting for ssh-agent socket to open...${NC}";
    waitForSocketToOpenOrFail

    echo -e "${YELLOW}[5/5] Populating pubkeys into ~/.ssh/keeper...${NC}";
    createSshPublicKeyFilesFromAgent

    echo -e "${GREEN}Success ! Keeper ssh-agent is up and running !${NC}";

    rm $config;

    exit 0
    ;;
stop)
    echo -e "${YELLOW}[1/3] Shutting down ssh-agent...${NC}";
    screen -X -S keeper-ssh quit

    echo -e "${YELLOW}[2/3] Removing SSH_AUTH_SOCK from bashrc...${NC}";
    removeSshAgentSocketToBashrc

    echo -e "${YELLOW}[3/3] Deleting pubkeys from ~/.ssh/keeper/...${NC}";
    deleteSshPublicKeys

    exit 0;
    ;;
*)  
    echo "Not supported, try reading the help with the -h parameter" 
    exit 1
    ;;
esac