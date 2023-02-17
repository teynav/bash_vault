#!/bin/bash
VAULT="testing.img"  # Remember to put .img here at end, Set your default vault  
SCRIPT_LOCATION="/home/$USER/bash_vault/bash_vault.sh" #Location of your bash_vault script 
VAULT_FOLDER=".vaults" #Change it only if you have changed default in script 
   
USER_R=$USER
FOLDER="/home/$USER/$VAULT_FOLDER"
PIPE="$FOLDER/pipe/m_pipe"
V_PIPE="$FOLDER/pipe/$VAULT"
 
if [ -p $V_PIPE ]; then 
    echo "Closing vault"
    echo close >> $V_PIPE 
else
   PASS=$(zenity --title="Enter Sudo Password" --password ) 
   echo $PASS | sudo -E -S $SCRIPT_LOCATION $USER_R $VAULT
fi 
