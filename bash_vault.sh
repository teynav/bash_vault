#!/bin/bash
## Author : Navneet Vikram Tey (teynav)
## Github : @teynav 
## Bugs?  : https://github.com/teynav/bash_vault/issues
#
MAX_VAULT_SIZE=30
VAULT_FOLDER=".vaults"
PASSWORD_LEN=8

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
    UUID="$(uuidgen)"
    CLOSE_VAULT=$1
    mkfifo "$PIPE/$UUID"
    echo "close:$UUID" > "$PIPE/$CLOSE_VAULT"
    while true; do
        read line < "$PIPE/$UUID"
        if [[ "$line" == "true" ]];then 
            rm -f "$PIPE/$UUID"
            return 0
        else
            rm -f "$PIPE/$UUID"
            return 1
        fi 
    done 
}
function closethis {
    rm -rf "$PIPE/$VAULTS"
    result=0
    if [[ "$MOUNT_FOLDER_NAME" != "" ]];then 
        umount "$FOLDER/$MOUNT_FOLDER_NAME" &>/dev/null 
        rm -rf "$FOLDER/$MOUNT_FOLDER_NAME" &>/dev/null 
        cryptsetup luksClose "$UUID" &>/dev/null
        result=$?
    fi
    if [ -p "$PIPE/$CALL_BACK_AT" ];then
        echo "Calling back at $CALL_BACK_AT"
        if [[ "$result" != "0" ]];then 
            echo false > "$PIPE/$CALL_BACK_AT"
            echo "Sent false"
        else 
            echo true > "$PIPE/$CALL_BACK_AT" 
            echo "Sent true"
        fi 
    fi
    exit 0
}
function createvault {
    USING_KEYFILE="0"
    keyfile=""
    d_input=$(zenity --list --column="Choose Action" "New Vault With Password" "New Vault With Keyfile" --height=300)
    if [[ "$d_input" == "New Vault With Keyfile" ]];then
        d_input=$(zenity --title="Creating Vault Using Keyfile" --forms --add-entry="Name Of Vault: " --text="Create your vault using Keyfile" --add-combo="Size(Default: 1024M)" --combo-values="1024M|2048M|5G|10G|20G" )
        if [[ $d_input == "" ]];then 
            Welcome="Please Input Name of Vault in Keyfile dialog"
            DONT_CHANGE_WELCOME=1
            return 1
        fi 
        USING_KEYFILE="1"
        keyfile=$(zenity --file-selection --title="Select a File For Vault")
    elif [[ "$d_input" == "New Vault With Password" ]];then 
        d_input=$(zenity --title="Vaults" --forms --add-entry="Name Of Vault: " --text="Create your vault" --add-password="Password of Vault" --add-combo="Size(Default: 1024M)" --combo-values="1024M|2048M|5G|10G|20G")
    else
        Welcome="Please select mode to create new vault in"
        DONT_CHANGE_WELCOME=1
        return 1
    fi 
    SAVEIFS=$IFS && IFS=$'|' && d_input=($d_input) ; IFS=$SAVEIFS
    nameofvault="$(echo ${d_input[0]} | xargs | sed 's/\.img$//g' )"
    tempname=$nameofvault
    nameofvault=$(echo $nameofvault | sed 's/ /-/g')
    pass="$(echo ${d_input[1]})"
    size="$(echo ${d_input[2]} | xargs )"
    pass_size=${#pass}
    if [[ "$USING_KEYFILE" == "1" ]];then 
        pass_size=$PASSWORD_LEN
        size=$pass
    fi 
    if [[ "$size" == "" ]];then 
        size="1024M"
    fi
    if [[ "$USING_KEYFILE" == "1" ]] && [[ "$keyfile" == "" ]];then 
        Welcome="Please Choose valid Keyfile"
        DONT_CHANGE_WELCOME=1
    elif [[ $pass_size -lt $PASSWORD_LEN ]];then
        Welcome="Failed! Enter Password with > $PASSWORD_LEN characters on vaults"
        DONT_CHANGE_WELCOME=1
        zenity --title="Vaults" --info --text="Failed! Password Size Should be >= $PASSWORD_LEN " --title="Error"
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
        echo "Now setup a password to $nameofvault"
        if [[ "$USING_KEYFILE" == "0" ]];then 
            echo -n $pass | cryptsetup  luksFormat "$FOLDER/$nameofvault.img" -d -
        else 
            echo "YES" | cryptsetup luksFormat "$FOLDER/$nameofvault.img" --key-file "$keyfile" 
        fi
        NID=$(notify-send -r $NID -p "Formatting Vault with LUKS ")
        UUID="$(uuidgen)"
        if [[ "$USING_KEYFILE" == "0" ]];then 
            echo $PASS | sudo -E -S sh -c "echo -n $pass | cryptsetup luksOpen \"$FOLDER/$nameofvault.img\" \"$UUID\" -d -"
        else 
            echo $PASS | sudo -E -S sh -c "cryptsetup luksOpen \"$FOLDER/$nameofvault.img\" \"$UUID\" --key-file \"$keyfile\""
        fi
        NID=$(notify-send -r $NID -p "Create new filesystem on $nameofvault.img")
        echo $PASS | sudo -S  $MKFS "/dev/mapper/$UUID" 
        NID=$(notify-send -r $NID  -p "Wrapping UP")
        echo $PASS | sudo -S  cryptsetup luksClose "$UUID"
        echo "Your vault has been created"
        Welcome="$nameofvault.img has been created"
        DONT_CHANGE_WELCOME=1
        if [[ "$USING_KEYFILE" == "1" ]];then
            echo $PASS | sudo -E -S  sh -c "echo \"$nameofvault.img\" >> \"$FOLDER/.filevaults\""
        fi 
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
    function eval_sucess_child {
        sucess=$1 
        message=$2
        if [[ "$sucess" != "0" ]];then
            if [ -p "$M_PIPE" ];then 
                if [[ "$MOTHER_RAN_ME" == "1" ]];then 
                    echo -e "$message" > "$M_PIPE"
                else
                    zenity --title="Vault Error" --info --text="$sucess"  
                fi 
            else 
                zenity --title="Vault Error" --info --text="$sucess"  
            fi 
            closethis 
        fi 

    }
    function modify_password {
        vault_name=$1
        action_to_take=$2
        file_for_logging="$FOLDER/.filevaults"
        is_using_keyfile=$( echo $PASS | sudo -E -S cat "$FOLDER/.filevaults" | grep "$vault_name" | wc -l )
        is_using_keyfile_bak=$is_using_keyfile
        if [[ "$is_using_keyfile" == "0" ]] && [[ "$action_to_take" == "" ]];then 
            d_input="$(zenity --list --title="$vault_name Passwords" --column="Modify Password" "Add Password" "Add Keyfile" "Change Password" "Remove Password"  --extra-button="Enable Keyfile")"
        elif [[ "$action_to_take" == "" ]];then 
            d_input="$(zenity --list --title="$vault_name Passwords" --column="Modify Password" "Add Password" "Add Keyfile" "Change Password" "Change Keyfile" "Remove Password" "Remove Keyfile" --extra-button="Disable Keyfile" )"
        fi
        if [[ "$d_input" == "Change Password" ]]||[[ "$d_input" == "Remove Password" ]];then 
            is_using_keyfile=0
        fi 
        if [[ "$d_input" == "Change Keyfile" ]]||[[ "$d_input" == "Remove Keyfile" ]];then 
            is_using_keyfile=1
        fi 
        if [[ "$d_input" == "" ]];then 
            Welcome="No Modification made for $vault_name"
            DONT_CHANGE_WELCOME=1
            return 1
        fi
        if [[ "$d_input" == "Disable Keyfile" ]] || [[ "$action_to_take" == "Disable Keyfile" ]];then
            zenity --question --title="Vaults" --text="This will disable keyfile, if you don't have password added to $vault_name you won't be able to use vault unless you re-enable Keyfile"
            answer=$?
            if [[ "$answer" == "0" ]];then
                echo $PASS | sudo -E -S sh -c "sed -i \"/$vault_name/d\" \"$file_for_logging\""
                Welcome="Keyfile disabled on $vault_name"
                DONT_CHANGE_WELCOME=1
                return 0
            else
                Welcome="Cancelled Toggling On Of Keyfile"
                DONT_CHANGE_WELCOME=1
                return 1 
            fi 
        elif [[ "$d_input" == "Enable Keyfile" ]] || [[ "$action_to_take" == "Enable Keyfile" ]];then 
            zenity --question --title="Vaults" --text="This will enable keyfile, if you don't have Keyfile added to $vault_name you won't be able to use vault unless you disable Keyfile"
            answer=$?
            if [[ "$answer" == "0" ]];then
                echo $PASS | sudo -E -S sh -c "echo \"$vault_name\" >> \"$file_for_logging\""
                Welcome="Keyfile enabled on $vault_name"
                DONT_CHANGE_WELCOME=1
                return 0
            else
                Welcome="Cancelled Toggling Off of Keyfile"
                DONT_CHANGE_WELCOME=1
                return 1
            fi 
            fi
            UUID=$(uuidgen)
            sucess=0
            prompt2="Remove"
            if [[ "$d_input" = Change* ]];then 
                prompt2="Change"
            fi
            prompt="Choose which keyfile to $prompt2"
            if [[ "$is_using_keyfile" == "0" ]];then
                prompt="Enter which password to $prompt2"
            fi 
            if [[ "$d_input" = Add* ]];then 
                prompt="Open Your $vault_name, to $d_input"
            fi 
            if [[ "$is_using_keyfile" == "0" ]];then
                pass="$(zenity --title="$prompt"  --password)"
                sucess=$?
                Welcome="You Cancelled $d_input for $vault_name"
                Welcome2="You entered wrong password for $vault_name"
                echo $PASS | sudo -E -S sh -c "echo -n $pass | cryptsetup luksOpen \"$FOLDER/$vault_name\" \"$UUID\" -d -"
            else 
                pass="$(zenity --file-selection --title="$prompt" 2>/dev/null )"
                sucess=$?
                Welcome="You Cancelled $d_input for $vault_name"
                Welcome2="You selected wrong keyfile for $vault_name"
                echo $PASS | sudo -E -S sh -c "cryptsetup luksOpen \"$FOLDER/$vault_name\" \"$UUID\" --key-file \"$pass\""
            fi

            if [[ "$sucess" != "0" ]];then
                DONT_CHANGE_WELCOME=1
                return 1
            fi 
            echo $PASS | sudo -E -S sh -c "cryptsetup luksClose  \"$UUID\" "
            sucess=$?
            if [[ "$sucess" != "0" ]];then
                Welcome=$Welcome2
                DONT_CHANGE_WELCOME=1
                return 1
            fi
            if [[ "$d_input" == "Add Password" ]] || [[ "$d_input" == "Change Password" ]];then
                d_input2="$(zenity --forms --title="Vaults" --text="New password for $vault_name" --add-password="New Password" --add-password="Verify New Password")"
                sucess=$?
                if [[ $sucess == "0" ]];then  
                    SAVEIFS=$IFS && IFS=$'|' && d_input2=($d_input2) ; IFS=$SAVEIFS
                    newp_1="$(echo ${d_input2[0]} )"
                    newp_2="$(echo ${d_input2[1]} )"
                    pass_size=${#newp_1}
                    if [[ "$newp_1" != "$newp_2" ]];then 
                        Welcome="Password's Don't Match, Exiting"
                        DONT_CHANGE_WELCOME=1
                        return 1
                    elif [[ "$newp_2" == "" ]];then 
                        Welcome="Please Enter All Parameters For Changing Password"
                        DONT_CHANGE_WELCOME=1
                        return 1
                    elif [[ $pass_size -lt $PASSWORD_LEN ]];then
                        Welcome="Password Too Short, Minimum Char $PASSWORD_LEN"
                        DONT_CHANGE_WELCOME=1
                        return 1
                    elif [[ "$newp_2" == "$pass" ]];then 
                        Welcome="Old and New password can't be same"
                        DONT_CHANGE_WELCOME=1
                        return 1
                    else
                        if [[ "$is_using_keyfile" == "0" ]];then 
                            if [[ "$d_input" == "Add Password" ]];then 
                                echo -n "$pass" | cryptsetup luksAddKey "$FOLDER/$vault_name" -d - <(echo -n "$newp_2")
                                sucess=$?
                            else
                                echo -n "$pass" | cryptsetup luksChangeKey "$FOLDER/$vault_name" -d - <(echo -n "$newp_2")
                                sucess=$?
                            fi
                        else 
                            if [[ "$d_input" == "Add Password" ]];then 
                                is_using_keyfile=0
                                echo -n "$newp_2" | cryptsetup luksAddKey --key-file "$pass" "$FOLDER/$vault_name" --new-keyfile - 
                                sucess=$?
                            else 
                                is_using_keyfile=0
                                echo -n "$newp_2" | cryptsetup luksChangeKey "$FOLDER/$vault_name" --key-file "$pass"  - 
                                sucess=$?
                            fi
                        fi 
                        if [[ $sucess != "0" ]];then
                            Welcome="Password Couldn't be Changed"
                            DONT_CHANGE_WELCOME=1
                            return 1
                        else
                            Welcome="Password changed for $vault_name"
                            DONT_CHANGE_WELCOME=1
                        fi 
                    fi 
                else
                    Welcome="Password Change Cancelled"
                    DONT_CHANGE_WELCOME=1
                    return 1
                fi
            elif [[ "$d_input" == "Add Keyfile" ]] || [[ "$d_input" == "Change Keyfile" ]];then
                new_key_file=$(zenity --file-selection --title="Choose A New Keyfile for $vault_name")
                if [[ "$new_key_file" != "" ]]; then 
                    if [[ "$is_using_keyfile" == "0" ]];then 
                        if [[ "$d_input" == "Add Keyfile" ]];then 
                                is_using_keyfile=0
                            echo -n "$pass" | cryptsetup luksAddKey "$FOLDER/$vault_name" --new-keyfile "$new_key_file" -d - 
                            sucess=$?
                        else
                            #WOULD NEVER EXECUTE EVER, LOGICALLY
                            echo "Logical error on branch of Add Keyfile with is_using_keyfile=0"
                            echo -n "$pass" | cryptsetup luksChangeKey "$FOLDER/$vault_name" -d - "$new_key_file" 
                            sucess=$?
                        fi
                    else 
                        if [[ "$d_input" == "Add Keyfile" ]];then 
                            cryptsetup luksAddKey --key-file "$pass" "$FOLDER/$vault_name" --new-keyfile "$new_key_file"
                            sucess=$?
                        else 
                            cryptsetup luksChangeKey "$FOLDER/$vault_name" --key-file "$pass" "$new_key_file"
                            sucess=$?
                        fi
                    fi
                    if [[ $sucess != "0" ]];then
                        Welcome="Keyfile Couldn't be Added for $vault_name"
                        DONT_CHANGE_WELCOME=1
                        return 1
                    else
                        Welcome="Keyfile added/changed for $vault_name"
                        DONT_CHANGE_WELCOME=1
                    fi 

                else
                    Welcome="$d_input Cancelled for $vault_name"

                fi
            else 
                zenity --question --title="Vaults" --text="IF YOU REMOVE YOUR PASSWORD OR KEYFILE, WITHOUT ADDING ANY OTHER PASSWORD/KEYFILE, YOU WILL LOSE ALL DATA, IF YOU UNDERSTAND THIS THEN CLICK OKAY TO PROCEED" --ok-label="OKAY, I UNDERSTAND" --cancel-label="NO, TAKE ME BACK"
                sucess=$?
                if [[ "$sucess" == "0" ]];then 
                    if [[ "$is_using_keyfile" == "0" ]];then 
                        echo -n "$pass" | cryptsetup luksRemoveKey "$FOLDER/$vault_name" -d -
                        this_issue="password"
                    else 
                        cryptsetup luksRemoveKey "$FOLDER/$vault_name" -d "$pass"
                        this_issue="Keyfile"
                    fi
                    is_using_keyfile=2
                    Welcome="Your $this_issue for $vault_name has been removed"
                    DONT_CHANGE_WELCOME=1
                else
                    Welcome="$d_input cancelled for $vault_name"
                    DONT_CHANGE_WELCOME=1
                    return 1
                fi 
                fi
                if [[ "$is_using_keyfile" != "$is_using_keyfile_bak" ]];then 
                    if [[ "$is_using_keyfile_bak" == "0" ]];then 
                        default="Password"
                        default2="Keyfile"
                        prompting="Enable Keyfile"
                    else 
                        default="Keyfile"
                        default2="Password"
                        prompting="Disable Keyfile"
                    fi 
                    zenity --question --title="Vaults" --text="You have made changes to your passphrases, Your default method of opening vault is $default, Do you want to change it? \nIf you don't change default you can open Modify Password, section on your vault and Enable/Disable Keyfile usage anytime" --cancel-label="No, Thanks" --ok-label="Change,it to $default2" 
                    if [[ "$?" == "0" ]];then
                        modify_password "$vault_name" "$prompting"
                    fi 
                fi 
            }
            function open {
                UUID=$(uuidgen)
                MOUNT_FOLDER_NAME="$VAULTS.data"
                CALL_BACK_AT=""
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
                sucess=$?
                MOUNT_FOLDER_NAME_BAK=$MOUNT_FOLDER_NAME
                MOUNT_FOLDER_NAME=""
                eval_sucess_child $sucess "Error: Couldn't create Folder $FOLDER/$MOUNT_FOLDER_NAME"
                MOUNT_FOLDER_NAME=$MOUNT_FOLDER_NAME_BAK
                is_using_keyfile=$(cat "$FOLDER/.filevaults" | grep "$VAULTS" | wc -l )
                sucess=0
                if [[ "$is_using_keyfile" == "0" ]];then
                    pass="$(zenity --title="Your Vault = $VAULTS"  --password)"
                    echo -n $pass | cryptsetup luksOpen "$FOLDER/$VAULTS" "$UUID" - 1> /dev/null
                    sucess=$?
                    eval_sucess_child $sucess "Error: Bad password for $VAULTS"
                else 
                    pass="$(sudo -u $USER_I zenity --file-selection --title="Select Keyfile for $VAULTS" 2>/dev/null )" 2>/dev/null
                    sucess=$?
                    eval_sucess_child $sucess "Error: No keyfile selected for $VAULTS"
                    if [[ "$pass" != "" ]];then
                        cryptsetup luksOpen "$FOLDER/$VAULTS" "$UUID" --key-file "$pass" 1> /dev/null
                        sucess=$?
                        eval_sucess_child $sucess "Error: Bad keyfile selected for $VAULTS"
                    else 
                        sucess=1
                    fi 
                fi 
                mount "/dev/mapper/$UUID" "$FOLDER/$MOUNT_FOLDER_NAME"
                sucess=$?
                eval_sucess_child $sucess "Error: Damaged $VAULTS, Needs to be deleted" > "$M_PIPE"
                chown  $USER_I:$USER_I "$FOLDER/$MOUNT_FOLDER_NAME"
                (sudo -u $USER_I xdg-open "$FOLDER/$MOUNT_FOLDER_NAME" &>/dev/null) & disown
                if [ -p "$M_PIPE" ];then
                    if [[ "$MOTHER_RAN_ME" == "1" ]];then 
                        echo okay > "$M_PIPE"
                    else
                        zenity --title="Vault Opened" --info --text="Your $VAULTS has been opened"
                    fi 
                else
                    zenity --title="Vault Opened" --info --text="Your $VAULTS has been opened"
                fi 

                while true; do
                    echo "IN loop"
                    read line < "$PIPE/$VAULTS"
                    if [[ "$line" == "close" ]];then
                        closethis
                        exit 0
                    elif [[ "$line" = close:* ]];then
                        CALL_BACK_AT=$(echo $line | sed 's/close://g' )
                        closethis
                    else 
                        (sudo -u $USER_I xdg-open "$FOLDER/$MOUNT_FOLDER_NAME" &>/dev/null) & disown
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
                    d_input=$(zenity --title="Vaults"  --text="$Welcome" --forms --add-combo="Action" --combo-values="Open|Close|Rename|Modify Password|Delete|Extend" --add-combo="Choose Vault" --combo-values="$A_VAULT" --show-header --extra-button "Create new" --cancel-label="Exit & Close" --extra-button "Exit & Wait")
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
                                waitonthis "$vault_a"
                                has_closed=$?
                                if [[ $has_closed == "0" ]];then 
                                    Welcome="$vault_a has been closed"
                                    DONT_CHANGE_WELCOME="1"
                                else
                                    Welcome="$vault_a couldn't be closed"
                                    DONT_CHANGE_WELCOME="1"
                                fi
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
                                waitonthis "$vault_a"
                                has_closed=$?
                                if [[ $has_closed == "0" ]];then 
                                    rm -rf "$FOLDER/$vault_a"
                                    Welcome="Vault $vault_a has been deleted"
                                    DONT_CHANGE_WELCOME=1
                                else
                                    Welcome="$vault_a couldn't be closed for deletion"
                                    DONT_CHANGE_WELCOME="1"
                                fi
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
                                    newname="$newname.img"
                                    if [ -p "$PIPE/$vault_a" ];then 
                                        waitonthis "$vault_a"
                                        has_closed=$?
                                        if [[ $has_closed == "0" ]];then 
                                            mv "$FOLDER/$vault_a" "$FOLDER/$newname"
                                            result=$?
                                            if [[ "$result" != "0" ]];then 
                                                Welcome="$vault_a Name Couldn't be changed"
                                                DONT_CHANGE_WELCOME=1
                                            else
                                                Welcome="$vault_a Name Changed to $newname"
                                                DONT_CHANGE_WELCOME=1
                                            fi 
                                        else
                                            Welcome="$vault_a couldn't be closed for Renaming"
                                            DONT_CHANGE_WELCOME="1"
                                        fi
                                    else
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
                            fi
                        elif [[ "$action" == "Extend" ]];then
                            sizern=$(du --apparent-size "$vault_a" | sed -e "s/$vault_a//g")
                            olds=$(( $sizern / 1024 / 1024 ))
                            echo Current Size "$olds"G
                            news=$(zenity --scale  --text="Choose new Size in GB" --min-value=$olds --value=$olds --max-value=$MAX_VAULT_SIZE  --step=2)
                            sucess=$?
                            has_closed=0
                            if [ -p "$PIPE/$vault_a" ];then 
                                waitonthis "$vault_a"
                                has_closed=$?
                            fi 
                            echo $news
                            if [[ "$has_closed" != "0" ]];then
                                Welcome="Couldn't close $vault_a for Resizing"
                                DONT_CHANGE_WELCOME=1
                            elif [[ "$news" == "$olds" ]];then 
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
                            elif [[ "$action" == "Modify Password" ]];then
                                modify_password "$vault_a"   
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
                            if [[ ! -f "$FOLDER/.filevaults" ]];then 
                                echo $PASS | sudo -S touch "$FOLDER/.filevaults"
                                echo $PASS | sudo -S chmod 600 "$FOLDER/.filevaults"
                            fi
                            fi
                            display
                        done 
