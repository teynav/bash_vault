# bash_vault

Combination of Cryptsetup+Zenity+Bash to created an encrypted Vault , with some extra perks !!

## Pre-requisite

![Installed App](./source/prerequisite.png "Check if you have these installed")

## Please wait while README gets updated 

While i do that, note Modify Password is something am still testing, it's really complex and so don't use it right now

## Configuration

There is nothing to configure as of now except

1. **MAX_VAULT_SIZE** by default on line #6 of the file, it's **30** ( *as in 30GB*), you can change it to whatever you seem fit
2. **VAULT_FOLDER** by default on line #7 it's **.vaults** which equated to ``` /home/user/.vaults ```, to change it to ``` /home/user/secret/whatever ``` change line #7 to **VAULT_FOLDER="secret/whatever"** , make sure folder name ``` whatever ``` doesn't exist

## Why This?

1. Easy to implement, doesn't require any other program which already doesn't come installed on many distro except zenity 
2. Here my "Homework" vault is 20GB (which can be extended to maximum depending upon **MAX_VAULT_SIZE**) If i have to backup it, I need to copy just 1 file which is 20GB, in contrast to gocryptfs where there are so many files and it slows down my backup speed.

## Why Shouldn't I use it? 

1. Every vault is secured with a password, you lose it and you lose the vault :"( 
2. If gocryptfs/any other encrypted software works for you, then don't fix what isn't broke ( although would love to see people trying this out)
3. Can't decrease the size of vault, only can increase it ( but there is a workaround )

## Walk me through these Zenity prompts?

1. Always your first prompt! Enter your sudo password. Why? Requires access to /dev/mapper to mount devices, you will be asked for sudo once during whole script lifecycle , to avoid any annoyance <3
![Installed App](./source/sudo.png "Your First Prompt, Asking for Sudo Password")  

2. What should script do next? 
    - If **VAULT_FOLDER** was not present , create it and then ask to create a new vault with given name and password, when creating vault **don't put .img at end** it will be done automatically
     ![Installed App](./source/create_vault.png "If your Sudo password is correct, On first run ") 
    - If **VAULT_FOLDER** was present, and no vaults were found ( because you deleted it), if pressed yes, it will give prompt as above
     ![Installed App](./source/no_vault.png "If your Sudo password is correct, And you have no vaults, check vault folder to see if you have vaults?")
    - If **VAULT_FOLDER** was present, and there are more than 0 vaults (vaults end with .img) it asks you to choose action for certain vault, check [Understanding default prompt](#understanding-default-prompt) 
     ![Installed App](./source/default.png "If your Sudo password is correct, And you have no vaults, check vault folder to see if you have vaults?")

## Understanding default Prompt

### Understanding Buttons 

1. Exit And Close -> Script will exit , and close all vaults ( Pressing Esc button would do same)
2. Exit and Wait -> Script will wait in background . 
   - to make it exit 
    ``` echo closeall >> /home/$USER/<vault_folder>/pipe/m_pipe ```<br>
    default ``` echo closeall >> /home/$USER/.vaults/pipe/m_pipe ```

   - to show default prompt again 
    ``` echo okay >> /home/$USER/<vault_folder>/pipe/m_pipe ```<br>
    default ``` echo closeall >> /home/$USER/.vaults/pipe/m_pipe ```

3. Create New -> Create new vault 
4. Okay button -> Takes input of Action and Vault, if no valid Action/Vault is provided, gives error

### Understanding Action 

1. Open -> Asks for password of said vault and mounts it in **VAULT_FOLDER/Random_UUID**, and then xdg-open it 
2. Close -> If vault is open then close it 
3. Delete -> Close vault if opened and then proceed to delete it 
4. Extend -> Show a scale between current SIZE of vault and **MAX_VAULT_SIZE** , ask user to choose 

In case of error/success Strings are updated and are shown here
![Installed App](./source/info_action.png "See the highlight in red sqaure!")

## What If

1. I ran bash_vault.sh from Terminal, What if Ctrl+C it, Do Vault Remain Open?? What happens?
   <br>
   No, signal like SIGINT is trapped and is used to close all vaults before exiting.
2. I am copying data to vault and i force closed it, what happens to my data? 
   <br>
   Depends on resilience of ext4 itself
3. I like how it works but my work is around one vault only, I don't need many :"( <br>
   <br>
   This is where power of scripting comes in , and you can use keybinding for that.
   For example in following script you can toggle mount by running it 
    ```bash 
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
       PASS=$(zenity  --password --title="Enter Sudo Password") 
       echo $PASS | sudo -E -S $SCRIPT_LOCATION $USER_R $VAULT
    fi
    ```
## Demonstration 

Right-Click on these gif and click "Open Image in New tab" to view them properly

1. Creating a new vault , and you can see force exit will close all mounts ( and so will rebooting your system)

![Video](./source/create_vault_and_foce_close.gif)

2. Extending the newly created vault from 1GB to 5GB 
   
![Video](./source/extend_video.gif)

3. Closing the vaults using script or zenity window

![Video](./source/closing_vault.gif)

4. Demonstration of my setup where bash_vault is bound to ALT+SHIFT+V `sh -c "~/bash_vault/bash_vault.sh"`

![Video](./source/my_setup.gif)

5. Demonstration of script mentioned in [What if](#what-if) section, which toggles mount of `testing.img` Vault on my machine

![Video](./source/example.gif)

Donations? , [PayPal](https://paypal.me/TalentedTey?locale.x=en_GB)
Suggestions? , [Signal](https://signal.me/#p/+919519873721)
