#!/bin/bash
## Author : Navneet Vikram Tey (teynav)
## Github : @teynav 
## Bugs?  : https://github.com/teynav/bash_vault/issues
#
MAX_VAULT_SIZE=30
VAULT_FOLDER=".vaults"

USER_I=$(whoami)
FOLDER="/home/$USER_I/$VAULT_FOLDER"
PIPE="$FOLDER/pipe"
M_PIPE="$FOLDER/pipe/m_pipe"
VAULTS=""
MKFS="mkfs.ext4"
SHOWN_INFO_ONCE=0
DONT_CHANGE_WELCOME=0
FILE_E=$(realpath $0)
if [[ -p "$M_PIPE" ]]; then
    echo okay > "$M_PIPE"
    exit 0
fi 
function close {
    if [[ "$JUSTCLOSE" == "yes" ]];then 
        exit 0 
    fi
    if [[ ! -d "$PIPE" ]];then 
        exit 0
    fi 
    cd "$PIPE" 
    for pipes in *.img
    do
        echo "close" > "$pipes" 
    done 
    cd ..
    rm -rf "$PIPE"
    exit 0
}
function dorightthing {
    files=$(ls -al "$PIPE/"*.img | wc -l )
    if [[ "$files" == "0" ]];then
        zenity --title="Vaults" --info --title="Exit" --text="None of the vaults are opened" --timeout=10
        close 
    else 
        if [[ "$1" == "" ]];then
            if [[ "$SHOWN_INFO_ONCE" == "0" ]];then 
                SHOWN_INFO_ONCE=1
                zenity --title="Vaults" --info --title="Waiting in Background" --text="To close all vaults \"echo closeall > $M_PIPE \"" --timeout 10
            fi 
        fi
        while true;do 
            read line < "$M_PIPE"
            echo "Received $line"
            if [[ "$line" == "closeall" ]];then 
                close 
                exit 0
            elif [[ "$line" == "okay" ]];then 
                return 0
            elif [[ "$line" = Error:* ]];then 
                zenity --title="Vaults" --warning --text="$line" --timeout=10
                return 0
            fi 
        done
    fi 
}
function waitonthis {
    while true;do
        sleep 5
    done
}
function closethis {
    rm -rf "$PIPE/$VAULTS"
    umount "$FOLDER/$MOUNT_FOLDER_NAME" &>/dev/null 
    rm -rf "$FOLDER/$MOUNT_FOLDER_NAME" &>/dev/null 
    cryptsetup luksClose "$UUID" &>/dev/null
    exit 0
}
function createvault {
    d_input=$(zenity --title="Vaults" --forms --add-entry="Name Of Vault: " --text="Create your vault" --add-password="Password of Vault" --add-combo="Size(Default: 1024M)" --combo-values="1024M|2048M|5G|10G|20G")
    SAVEIFS=$IFS && IFS=$'|' && d_input=($d_input) ; IFS=$SAVEIFS
    nameofvault="$(echo ${d_input[0]} | xargs | sed 's/\.img$//g' )"
    tempname=$nameofvault
    nameofvault=$(echo $nameofvault | sed 's/ /-/g')
    pass="$(echo ${d_input[1]} | xargs )"
    size="$(echo ${d_input[2]} | xargs )"
    if [[ "$size" == "" ]];then 
        size="1024M"
    fi 
    if [[ "$pass" == "" ]];then 
        Welcome="You forgot to put enter password for new vault"
        DONT_CHANGE_WELCOME=1
        zenity --title="Vaults" --info --text="Incomplete info was given, no Password provided" --title="Error"
    elif [[ "$nameofvault" == "" ]];then 
        Welcome="You forgot to put Name of Vault"
        DONT_CHANGE_WELCOME=1
        zenity --title="Vaults" --info --text="Incomplete info was given, no vault name was given" --title="Error"
    elif [ -f "$FOLDER/$tempname.img" ];then 
        zenity --title="Vaults" --info --text="Vault Already Exists" --title="Error"
        Welcome="Try with different vault name !!"
        DONT_CHANGE_WELCOME=1
    elif ! [[ $nameofvault =~ ^[0-9a-zA-Z._-]+$ ]]; then
        Welcome="Special Character allowed are ._- , Invalid name !!"
        DONT_CHANGE_WELCOME=1
    else 
        nameofvault=$tempname
        echo "Creating your vault..."
        NID=$(notify-send  -p "Starting to create your vault")
        dd if=/dev/zero of="$FOLDER/$nameofvault.img" bs=1 count=0 seek=$size 
        #       VAULTS="$VAULTS:$FOLDER/$nameofvault.img"
        echo "Now setup a password to $nameofvault"
        echo -n $pass | cryptsetup  luksFormat "$FOLDER/$nameofvault.img" -d -
        NID=$(notify-send -r $NID -p "Formatting Vault with LUKS ")
        UUID="$(uuidgen)"
        echo "Setting up your vault, you will be asked for password again!!!"
        echo $PASS | sudo -E -S sh -c "echo -n $pass | cryptsetup luksOpen \"$FOLDER/$nameofvault.img\" \"$UUID\" -d -"
        echo 40
        NID=$(notify-send -r $NID -p "Create new filesystem on $nameofvault.img")
        echo $PASS | sudo -S  $MKFS "/dev/mapper/$UUID" 
        echo 70
        NID=$(notify-send -r $NID  -p "Wrapping UP")
        echo $PASS | sudo -S  cryptsetup luksClose "$UUID"
        echo "Your vault has been created"
        Welcome="$nameofvault.img has been created"
        DONT_CHANGE_WELCOME=1
        echo 100
        fi
    }

    function newinstall {
        mkdir "$FOLDER"
        if [ ! -d "$FOLDER" ];then 
            zenity --info --title="\$VAULT_FOLDER Has been configured wrong, Exiting \nCheck github page"
            exit 0
        fi 
        createvault 
    }

    function open {
        UUID=$(uuidgen)
        MOUNT_FOLDER_NAME="$VAULTS.data"
        trap closethis  SIGTERM SIGINT EXIT
        if [ ! -d "$PIPE"  ];then 
            mkdir "$PIPE"  
            mkfifo "$PIPE/$VAULTS"
            chown -R $USER_I:$USER_I "$FOLDER/pipe"
            MOTHER_RAN_ME=0
        elif [ ! -p "$PIPE/$VAULTS" ];then
            mkfifo "$PIPE/$VAULTS"
            chown -R $USER_I:$USER_I "$FOLDER/pipe"
            MOTHER_RAN_ME=0
        fi 
        mkdir "$FOLDER/$MOUNT_FOLDER_NAME" 
        pass="$(zenity --title="Your Vault = $VAULTS"  --password)"
        echo -n $pass | cryptsetup luksOpen "$FOLDER/$VAULTS" "$UUID" - 1> /dev/null
        sucess=$?
        if [[ "$sucess" != "0" ]];then
            if [ -p "$M_PIPE" ];then 
                echo -e "Error: Bad password for $VAULTS \n Please Try Again" > "$M_PIPE"
            else 
                zenity --title="Vault Error" --info --text="Error: Bad password for $VAULTS \n Please Try Again"  
            fi 
            closethis 
        fi 
        mount "/dev/mapper/$UUID" "$FOLDER/$MOUNT_FOLDER_NAME"
        sucess=$?
        if [[ "$sucess" != "0" ]];then
            if [ -p "$M_PIPE" ];then 
                echo -e "Error: Damaged $VAULTS, Needs to be deleted" > "$M_PIPE"
            else 
                zenity --title="Vault Error" --info --text="Error: Damaged $VAULTS \n Need to be deleted"  
            fi 
            closethis
        fi 
        chown -R $USER_I:$USER_I "$FOLDER/$MOUNT_FOLDER_NAME"
        (sudo -u $USER_I xdg-open "$FOLDER/$MOUNT_FOLDER_NAME" &>/dev/null) & disown
        if [ -p "$M_PIPE" ];then
            if [[ "$MOTHER_RAN_ME" == "1" ]];then 
                echo okay > "$M_PIPE"
            else
                notify-send -p "Your $VAULTS has been opened"
            fi 
        else
            notify-send -p "Your $VAULTS has been opened"
        fi 

        while true; do
            echo "IN loop"
            read line < "$PIPE/$VAULTS"
            if [[ "$line" == "close" ]];then
                closethis
                exit 0
            else 
                sudo -u $USER_I xdg-open "$FOLDER/$MOUNT_FOLDER_NAME"
            fi
        done 
    }

    function display {
        echo "Please select what you want to open"
        A_VAULT=""
        ERROR_V=""
        WELCOME_E=""
        for elem in *.img 
        do
            if [[ "$elem" != "*.img" ]]; then
                tem_element=$elem
                tem_element=$(echo $tem_element | sed 's/ /a/g')
                if ! [[ $tem_element =~ ^[0-9a-zA-Z._-]+$ ]]; then
                    if [[ "$WELCOME_E" == "" ]];then 
                        WELCOME_E=$elem
                    else 
                        WELCOME_E="$A_VAULT, $elem"
                    fi 
                else
                    if [[ "$A_VAULT" == "" ]];then 
                        A_VAULT=$elem
                    else 
                        A_VAULT="$A_VAULT|$elem"
                    fi 
                fi 
            fi
        done

        if [[ "$WELCOME_E" != "" ]];then
            Welcome="$WELCOME_E have bad name"
        fi 
        if [[ "$A_VAULT" == "" ]];then
            result=""
            if [[ "$WELCOME_E" == "" ]];then
                zenity --title="Vaults" --question --text="No Vault Found, Create One?"
                result=$?
            else 
                zenity --title="Vaults" --question --text="$WELCOME_E have bad name\nCheck \"$FOLDER\"\nNo Other Vault Found\nCreate Another Vault?"
                result=$?
            fi 

            if [[ "$result" == "0" ]];then 
                createvault
            else 
                close 
            fi
        else 
            d_input=$(zenity --title="Vaults"  --text="$Welcome" --forms --add-combo="Action" --combo-values="Open|Close|Rename|Delete|Extend" --add-combo="Choose Vault" --combo-values="$A_VAULT" --show-header --extra-button "Create new" --cancel-label="Exit & Close" --extra-button "Exit & Wait")
            returncode=$?
            if [[ "$d_input" == "Create new" ]]; then 
                createvault
            elif [[ "$d_input" == "Exit & Wait" ]];then
                dorightthing
            elif [[ "$d_input" == "" ]]; then
                close 
            else  
                SAVEIFS=$IFS && IFS=$'|' && d_input=($d_input) ; IFS=$SAVEIFS
                action="$(echo ${d_input[0]} | xargs )"
                vault_a="$(echo ${d_input[1]} | xargs )"
                if [[ $action == "" ]] || [[ "$vault_a" == "" ]];then 
                    Welcome="Both Action and Vault Name Required"
                    DONT_CHANGE_WELCOME=1
                elif [[ $action == "Open" ]];
                then
                    if [ -p "$PIPE/$vault_a" ];then 
                        echo open >> "$PIPE/$vault_a"
                    else 
                        mkfifo "$PIPE/$vault_a"
                        echo $PASS | sudo -S "$FILE_E" $USER_I "$vault_a" & disown
                        dorightthing 1
                        O_VAULT+=($!)
                        sleep 2

                    fi 
                    if [ -p "$PIPE/$vault_a" ];then 
                        Welcome="$vault_a has been opened"
                        DONT_CHANGE_WELCOME="1"
                    else
                        Welcome="$vault_a couldn't be opened"
                        DONT_CHANGE_WELCOME="1"
                    fi 
                elif [[ "$action" == "Close" ]];then
                    if [ -p "$PIPE/$vault_a" ];then 
                        Welcome="$vault_a has been closed"
                        echo close >> "$PIPE/$vault_a"
                        DONT_CHANGE_WELCOME="1"
                    else
                        Welcome="$vault_a wasn't opened, Select Open to Open"
                        DONT_CHANGE_WELCOME="1"
                    fi 
                elif [[ "$action" == "Delete" ]];then
                    zenity --title="Vaults" --question --text="Are you sure to delete $vault_a?"
                    response=$?
                    if [[ "$response" == "1" ]]; then
                        echo "Deletion cancelled"
                        Welcome="Vault $vault_a was NOT deleted"
                        DONT_CHANGE_WELCOME=1
                    elif [ -p "$PIPE/$vault_a" ];then 
                        echo close >> "$PIPE/$vault_a"
                        sleep 3
                        rm -rf "$FOLDER/$vault_a"
                        Welcome="Vault $vault_a has been deleted"
                        DONT_CHANGE_WELCOME=1
                    else 
                        rm -rf "$FOLDER/$vault_a"
                        Welcome="Vault $vault_a has been deleted"
                        DONT_CHANGE_WELCOME=1
                    fi
                elif [[ "$action" == "Rename" ]];then
                    vault_old_name="$(echo $vault_a | sed 's/\.img$//g' )"
                    newname="$(zenity --entry --entry-text="$vault_old_name" --text="Enter new name" | sed 's/\.img$//g')"
                    result=$?
                    if [[ "$result" != "0" ]];then 
                        Welcome="$vault_a Name Change Was Cancelled"
                        DONT_CHANGE_WELCOME=1
                    else 
                        newname_spaceless="$(echo $newname | sed 's/ //g')"
                         if ! [[ $newname_spaceless =~ ^[0-9a-zA-Z._-]+$ ]]; then
                          Welcome="$newname Has invalid characters, Name Change Cancelled"
                          DONT_CHANGE_WELCOME=1
                         else
                             if [ -p "$PIPE/$vault_a" ];then 
                                 echo close > "$PIPE/$vault_a"
                                 sleep 2
                             fi
                             newname="$newname.img"
                             mv "$FOLDER/$vault_a" "$FOLDER/$newname"
                             result=$?
                             if [[ "$result" != "0" ]];then 
                                 Welcome="$vault_a Name Couldn't be changed"
                                 DONT_CHANGE_WELCOME=1
                             else
                                 Welcome="$vault_a Name Changed to $newname"
                                 DONT_CHANGE_WELCOME=1
                             fi 
                         fi 
                    fi 
                elif [[ "$action" == "Extend" ]];then
                    sizern=$(du --apparent-size "$vault_a" | sed -e "s/$vault_a//g")
                    olds=$(( $sizern / 1024 / 1024 ))
                    echo Current Size "$olds"G
                    news=$(zenity --scale  --text="Choose new Size in GB" --min-value=$olds --value=$olds --max-value=$MAX_VAULT_SIZE  --step=2)
                    sucess=$?
                    if [ -p "$PIPE/$vault_a" ];then 
                        echo close >> "$PIPE/$vault_a"
                        sleep 3
                    fi 
                    echo $news
                    if [[ "$news" == "$olds" ]];then 
                        zenity --title="Vaults" --info --text="Old Size is equal to new size, Exiting"
                        Welcome="Enter a different size for $vault_a"
                        DONT_CHANGE_WELCOME=1
                    elif [[ "$sucess" != "0" ]]; then
                        Welcome="Extending $vault_a was cancelled"
                        DONT_CHANGE_WELCOME=1
                    else 
                        pass="$(zenity  --title="Opening $vault_a" --text="Please enter password for $vault_a" --password)"
                        UUID=$(uuidgen)
                        echo $PASS | sudo -E -S sh -c "echo -n $pass | cryptsetup luksOpen \"$FOLDER/$vault_a\" \"$UUID\" -d -"
                        sucess=$?
                        if [[ "$sucess" != "0" ]];then 
                            zenity --title="Vaults" --info --text="You entered wrong password"
                        else

                            NID=$(notify-send -p "First Closing Up Everything")
                            echo $PASS | sudo -S  cryptsetup luksClose "$UUID"
                            echo 20
                            dd if=/dev/zero of="$vault_a" bs=1 count=0 seek="$news"G
                            NID=$(notify-send  -r $NID -p "Opening and Trying to Resize")
                            echo $PASS | sudo -E -S sh -c "echo -n $pass | cryptsetup luksOpen \"$FOLDER/$vault_a\" \"$UUID\" -d -"
                            echo 40
                            echo $PASS | sudo -E -S sh -c "echo -n $pass | cryptsetup resize  \"$UUID\" -d -"
                            echo 60
                            NID=$(notify-send  -r $NID -p "Resizing Filesystem")
                            echo $PASS | sudo -E -S e2fsck -fy  /dev/mapper/$UUID
                            echo 80
                            echo $PASS | sudo -E -S resize2fs  /dev/mapper/$UUID
                            NID=$(notify-send  -r $NID -p "Wrapping UP")
                            echo $PASS | sudo -S  cryptsetup luksClose "$UUID"
                            echo 100
                            fi 
                        fi
                    else 
                        dorightthing
                    fi

                fi
                if [[ "$DONT_CHANGE_WELCOME" != "0" ]] ; then 
                    DONT_CHANGE_WELCOME=0
                elif [[ "$Welcome" != "" ]];then 
                    Welcome="Choose Another Action or Exit"
                fi
            fi

        }

        if [ $UID -eq 0 ];then
            USER_I=$1
            VAULTS=$2
            FOLDER="/home/$USER_I/$VAULT_FOLDER"
            PIPE="$FOLDER/pipe"
            M_PIPE="$FOLDER/pipe/m_pipe"
            MOTHER_RAN_ME=1
            if [ $1 == 0 ];then 
                exit 1
            fi
            echo "Opening vault"
            open
            echo "Done opening vault"
            exit 0
        fi
        trap close  SIGTERM SIGINT EXIT
        if [[ ! -d $FOLDER ]];then
            if [ $UID -eq 0 ];then 
                echo "Run this as user, not root"
            fi 
            echo "Taking it as a new installation"
            echo "Creating new folder $FOLDER"
            echo "This will be location of your vaults"
            if [[ "$PASS" == "" ]];
            then 
                PASS="$(zenity  --title="Please enter your sudo password"  --password)"
            fi
            echo $PASS | sudo -S echo "Checking if sudo password is correct"
            result=$?
            if [[ "$result" != "0" ]];then 
                zenity --title="Vault" --warning --text="Wrong Sudo Password Was Entered, Exiting"
                exit 0
            fi 

            newinstall
            fi
            O_VAULT=()
            mkdir "$PIPE"
            mkfifo "$M_PIPE"
            cd "$FOLDER"
            echo "Welcome to your vaults"
            Welcome=""
            while true; do
                if [[ "$Welcome" == "" ]];
                then
                    Welcome="Welcome to vaults"
                fi
                if [[ "$PASS" == "" ]];
                then 
                    PASS="$(zenity  --title="Please enter your sudo password"  --password)"
                    echo $PASS | sudo -S echo "Checking if sudo password is correct"
                    result=$?
                    if [[ "$result" != "0" ]];then 
                        zenity --title="Vault" --warning --text="Wrong Sudo Password Was Entered, Exiting"
                        exit 0
                    fi 
                    fi
                    display
                done 
