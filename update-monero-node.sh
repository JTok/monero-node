#!/bin/bash

# v1.0 - 2022.09.24

# if the script is running as root abort
if [[ $EUID -eq 0 ]]; then
  echo "This script cannot be run as root"
  exit 1
fi


# check if the monero service already exists.
echo "checking if the monerod service already exists"
if systemctl --user list-units --full -all | grep -Fq "monerod.service"; then
  echo "the monerod service already exists, so no need to recreate it"
else
  echo "the monerod service does not exist, so creating it now"

  # enable linger so that the service will start at boot before the user logs in
  echo "enabling lingering for current user so that the service will start at boot"
  loginctl enable-linger "$USER"

  # create the user service directory
  echo "creating directory for user services"
  mkdir -p "$HOME/.config/systemd/user"

  # create the service file
  echo "creating monerod.service file"
  echo "[Unit]
Description=monerod
After=network.target

[Service]
Type=forking
PIDFile=$HOME/.bitmonero/monerod.pid
ExecStart=$HOME/monero/current/monerod --config-file=$HOME/.bitmonero/bitmonero.conf --detach --pidfile $HOME/.bitmonero/monerod.pid

[Install]
WantedBy=default.target
" > "$HOME/.config/systemd/user/monerod.service"

  # enable the service and reload the daemons so systemd will see it
  echo "enabling the service and reloading daemons"
  systemctl --user enable monerod.service
  systemctl --user daemon-reload

  # check to make sure the service was created successfully before continuing
  echo "checking if the service installed successfully"
  if systemctl --user list-units --full -all | grep -Fq "monerod.service"; then
    echo "service installed successfully. continuing..."
  else
    echo "the service failed to install. aborting script"
    exit
  fi

fi


# check if bitmonero.conf already exists
echo "checking if the bitmonero.conf file already exists"
if [[ -f "$HOME/.bitmonero/bitmonero.conf" ]]; then
  echo "bitmonero.conf exists. so no need to recreate it"
else
  echo "bitmonero.conf does not exist. creating file."

  # create the .bitmonero directory
  echo "creating the bitmonero directory"
  mkdir -p "$HOME/.bitmonero"

  # ask user for credentials to use when connecting to the monerod service from their wallet
  printf "\n\nPlease choose a username and password to use to connect to the monerod service when using a wallet\n"
  while :
  do
    read -r -p 'username: ' username

    if [ -n "$username" ]; then
      break;
    fi

    if [ -z "$username" ]; then
      printf "\nerror: username cannot be blank. please try again\n\n" >&2
    else
      printf "\nerror: something went wrong, but I can't tell what. please try again\n\n" >&2
    fi
  done
  while :
  do
    read -r -sp 'password: ' password
    echo ""
    read -r -sp 'verify password: ' verify

    if [ "$password" == "$verify" ] && [ -n "$password" ]; then
      printf "\npasswords matched\n"
      break;
    fi

    if [ -z "$password" ]; then
      printf "\nerror: password cannot be blank. please try again\n\n" >&2
    elif [ "$password" != "$verify" ]; then
      printf "\nerror: passwords did not match. please try again\n\n" >&2
    else
      printf "\nerror: something went wrong, but I can't tell what. please try again\n\n" >&2
    fi
  done

  echo "Thank you. bitmonero.conf will be generated with an rpc-login user the username: $username"

  # write the bitmonero.conf file
  echo "creating the bitmonero.conf file"
  echo "# $HOME/.bitmonero/bitmonero.conf

# Data directory (blockchain db and indices)
data-dir=$HOME/.bitmonero

# Log file
log-file=/var/log/monero/monerod.log
max-log-file-size=0            # Prevent monerod from managing the log files; we want logrotate to take care of that

# P2P full node
#p2p-bind-ip=0.0.0.0            # Bind to all interfaces (the default)
#p2p-bind-port=18080            # Bind to default port
hide-my-port=1                  # prevents nodes from spreading your IP to other nodes

# RPC open node
rpc-bind-ip=0.0.0.0            # Bind to all interfaces
rpc-bind-port=18081            # Bind on default port
confirm-external-bind=1        # Open node (confirm)
restricted-rpc=1               # Prevent unsafe RPC calls
no-igd=1                       # Disable UPnP port mapping

# Slow but reliable db writes
#db-sync-mode=safe

# Emergency checkpoints set by MoneroPulse operators will be enforced to workaround potential consensus bugs
# Check https://monerodocs.org/infrastructure/monero-pulse/ for explanation and trade-offs
enforce-dns-checkpointing=1

out-peers=64              # This will enable much faster sync and tx awareness; the default 8 is suboptimal nowadays
in-peers=1024             # The default is unlimited; we prefer to put a cap on this

#limit-rate-up=1048576     # 1048576 kB/s == 1GB/s; a raise from default 2048 kB/s; contribute more to p2p network
limit-rate-down=1048576   # 1048576 kB/s == 1GB/s; a raise from default 8192 kB/s; allow for faster initial sync

# Set login for daemon
rpc-login=$username:$password
" > "$HOME/.bitmonero/bitmonero.conf"

  echo "To edit the service configuration you can edit $HOME/.bitmonero/bitmonero.conf"
  echo "IMPORTANT: the service will not be publically accessible and is running on port 18081"
  read -r -p "Note the port above and press any key to continue ..."

  # check if bitmonero.conf was successfully created
  echo "checking if the bitmonero.conf was created successfully"
  if [[ -f "$HOME/.bitmonero/bitmonero.conf" ]]; then
    echo "bitmonero.conf successfully created. continuing..."
  else
    echo "bitmonero.conf was not successfully created. aborting script"
    exit
  fi
fi



# move to the current user's home directory
cd "$HOME" || exit

# check to see if their is a current version of monero installed
if [ -d "$HOME/monero/current/" ]; then
  current_version_installed=true
else
  current_version_installed=false
fi


# if there is a current version, store the currently running version in a variable so it can be compared to the downloaded version later
if [ "$current_version_installed" == true ]; then
  current_full_version=$(find "$HOME/monero/" -type f -name "*.current")
  # strip the full path and store just the basename
  current_full_version=$(basename "$current_full_version")
  # strip the file extension and store just the version
  current_full_version="${current_full_version%%.current*}"
fi


# download latest version of monero
echo "downloading the latest monero version"
wget https://downloads.getmonero.org/cli/linux64


## verify the signing key ##
# get the binaryfate signing key
echo "getting the binaryfate signing key"
wget -O binaryfate.asc https://raw.githubusercontent.com/monero-project/monero/master/utils/gpg_keys/binaryfate.asc

# store the expected key in a variable
expected_key='pub   rsa4096/F0AF4D462A0BDF92 2019-12-12 [SCEA]
      Key fingerprint = 81AC 591F E9C4 B65C 5806  AFC3 F0AF 4D46 2A0B DF92
uid                           binaryFate <binaryfate@getmonero.org>
sub   rsa4096/2593838EABB1F655 2019-12-12 [SEA]'

# store the downloaded key in a variable
downloaded_key=$(gpg --keyid-format long --with-fingerprint binaryfate.asc)


# compare the expected key and the downloaded key
printf "checking if the downloaded key is what is expected\n"
if [[ "$expected_key" == "$downloaded_key" ]]; then
  # if the keys match continue
  echo "the download key matched the expected key, continuing"
else
  # if the keys do not match, ask if the keys should be compared manually
  printf "the downloade key did not match the expected key\n"
  while true; do
    read -r -p "Do you want to compare the keys manually? " yn
    case $yn in
      [Yy]* )
        printf "continuing...\n"
        break
        ;;
      [Nn]* )
        echo "cleaning up and exiting script"
        # remove downloaded files - compressed file, signing key, and hash file
        rm -fv "$HOME/linux64"
        rm -fv "$HOME/binaryfate.asc"
        rm -fv "$HOME/hashes.txt"
        exit
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done

  # show what the expected signing key is
  printf "the fingerprint should look like this:\n"
  echo "$expected_key"
  printf "\n\n"

  # show the downloaded signing key
  gpg --keyid-format long --with-fingerprint binaryfate.asc

  # ask the user to confirm the keys match
  while true; do
    read -r -p "Do the above keys match? " yn
    case $yn in
      [Yy]* )
        printf "continuing...\n";
        break
        ;;
      [Nn]* )
        echo "cleaning up and exiting script"
        # remove downloaded files - compressed file, signing key, and hash file
        rm -fv "$HOME/linux64"
        rm -fv "$HOME/binaryfate.asc"
        rm -fv "$HOME/hashes.txt"
        exit
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done
fi


## verify hashes.txt is authentic ##
# get the hashes.txt file
echo "getting the hashes.txt file"
wget -O hashes.txt https://www.getmonero.org/downloads/hashes.txt

# store the expected hashes.txt signature in a variable
expected_hashes_signature='gpg:                using RSA key 81AC591FE9C4B65C5806AFC3F0AF4D462A0BDF92
gpg: Good signature from "binaryFate <binaryfate@getmonero.org>" [unknown]
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: 81AC 591F E9C4 B65C 5806  AFC3 F0AF 4D46 2A0B DF92'

# store the downloaded hashes.txt signature in a variable
downloaded_hashes_signature=$(gpg --verify hashes.txt 2>&1)
# remove the first line that contains the timestamp
downloaded_hashes_signature=$(sed '1d' <<< "$downloaded_hashes_signature")

# compare the expected signature and the downloaded signature
printf "checking if the hashes.txt signature is what is expected\n"
if [[ "$expected_hashes_signature" == "$downloaded_hashes_signature" ]]; then
  # if the signatures match continue
  echo "hashes.txt signatures matched, continuing"
else
  # if the signatures do not match, ask if the signatures should be compared manually
  printf "hashes.txt signatures did not match\n"
  while true; do
    read -r -p "Do you want to compare the hashes.txt signatures manually? " yn
    case $yn in
      [Yy]* )
        printf "continuing...\n"
        break
        ;;
      [Nn]* )
        echo "cleaning up and exiting script"
        # remove downloaded files - compressed file, signing key, and hash file
        rm -fv "$HOME/linux64"
        rm -fv "$HOME/binaryfate.asc"
        rm -fv "$HOME/hashes.txt"
        exit
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done

  # show what the expected hashes.txt signature is
  printf "you should see the following lines if it is authentic:\n"
  echo "$expected_hashes_signature"
  printf "\n\n"

  # show the downloaded hashes.txt signature
  gpg --verify hashes.txt

  # ask the user to confirm the signatures match
  while true; do
    read -r -p "Do the above hashes.txt signatures match? " yn
    case $yn in
      [Yy]* )
        printf "continuing...\n"
        break
        ;;
      [Nn]* )
        echo "cleaning up and exiting script"
        # remove downloaded files - compressed file, signing key, and hash file
        rm -fv "$HOME/linux64"
        rm -fv "$HOME/binaryfate.asc"
        rm -fv "$HOME/hashes.txt"
        exit
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done
fi

## verify the downloaded installer ##
# store the sha for the new monero version that was downloaded in a variable
linux64_full_shasum="$(shasum -a 256 linux64)"
# store just the hash so that it doesn't contain the filename in a variable
linux64_shasum="${linux64_full_shasum%% *}"

# check that the hash for the new monero that was downloaded is in hashes.txt
printf "checking hashes.txt for the hash of the new monero file that was downloaded\n"
if grep -Fq "$linux64_shasum" hashes.txt; then
  # if the hash is found let the user know and display the line
  echo "the hash for the new monero version that was downloaded was found in the following line:"
  # store the output of the grep command in a variable for use later and display it
  hash_shasum_line=$(grep -F "$linux64_shasum" hashes.txt)
  echo "$hash_shasum_line"

  # save the version number from the hash before continuing
  # first strip the hash and space from the start of the line the hash was found on in hashes.txt and store it in a variable
  hash_full_version="${hash_shasum_line##* }"
  # second strip the file extension from the end and update the variable
  hash_full_version="${hash_full_version%%.tar.bz2*}"
else
  # if the hash is not found let the user know and exit the script
  echo "the hash for the new monero version that was downloaded was not found. cleaning files and aborting script"
  # remove downloaded files - compressed file, signing key, and hash file
  rm -fv "$HOME/linux64"
  rm -fv "$HOME/binaryfate.asc"
  rm -fv "$HOME/hashes.txt"
  exit
fi


## extract the new monero version ##
# create a directory to extract the new monero version to if it doesn't already exist
mkdir -p "$HOME/monero/"
# extract the new monero version that was downloaded to the monero directory
echo "extracting the new monero version that was downloaded"
tar -xvf "$HOME/linux64" -C "$HOME/monero/"


## verify that the current version doesn't match the version number of the extracted download ##
# loop through all the directories and store whatever the last one is in a variable
# (there should only be one directory, so no need to store them as an array and search the array)
for d in "$HOME"/monero/*; do
  # check to see if the current object in $d is a directory
  if [ -d "$d" ]; then
    # if it is a directory store just the basename, not the full path, in a variable
    download_full_version=$(basename "$d")
  fi
done

# compare the current version number to the downloaded version number if a current version exists
if [ "$current_version_installed" == true ]; then
  printf "checking if the current version number matches the downloaded version number\n"
  if [[ "$current_full_version" != "$download_full_version" ]]; then
    # if the versions do not match continue
    echo "the versions did not match, continuing"
  else
    # if the versions do match, ask if the versions should be compared manually
    printf "the versions matched\n"
    while true; do
      read -r -p "Do you want to compare the versions manually? " yn
      case $yn in
        [Yy]* )
          printf "continuing...\n"
          break
          ;;
        [Nn]* )
          echo "cleaning up and exiting script"
          # remove downloaded files - compressed file, extracted file, signing key, and hash file
          rm -fv "$HOME/linux64"
          rm -rfv "$HOME/monero/$download_full_version"
          rm -fv "$HOME/binaryfate.asc"
          rm -fv "$HOME/hashes.txt"
          exit
          ;;
        * )
          echo "Please answer yes or no."
          ;;
      esac
    done

    # show the current version number
    echo "current version number: $current_full_version"

    # show the downloaded version number
    echo "downloaded version number: $download_full_version"

    # ask the user to confirm the versions match
    while true; do
      read -r -p "Do the above versions match? " yn
      case $yn in
        [Yy]* )
          echo "cleaning up and exiting script"
          # remove downloaded files - compressed file, extracted file, signing key, and hash file
          rm -fv "$HOME/linux64"
          rm -rfv "$HOME/monero/$download_full_version"
          rm -fv "$HOME/binaryfate.asc"
          rm -fv "$HOME/hashes.txt"
          exit
          ;;
        [Nn]* )
          printf "continuing...\n"
          break
          ;;
        * )
          echo "Please answer yes or no."
          ;;
      esac
    done
  fi
fi


## verify that the version from the hashes.txt file matches the version number of the extracted download ##
# store just the version number from the hashes.txt file
hash_version_number="${hash_full_version##*v}"

# store just the version number from the directory
download_version_number="${download_full_version##*v}"

# compare the hashes.txt version number to the downloaded version number
printf "checking if the hashes.txt version number matches the downloaded version number\n"
if [[ "$hash_version_number" == "$download_version_number" ]]; then
  # if the versions match continue
  echo "the versions matched, continuing"
else
  # if the versions do not match, ask if the versions should be compared manually
  printf "the versions did not match\n"
  while true; do
    read -r -p "Do you want to compare the versions manually? " yn
    case $yn in
      [Yy]* )
        printf "continuing...\n"
        break
        ;;
      [Nn]* )
        echo "cleaning up and exiting script"
        # remove downloaded files - compressed file, extracted file, signing key, and hash file
        rm -fv "$HOME/linux64"
        rm -rfv "$HOME/monero/$download_full_version"
        rm -fv "$HOME/binaryfate.asc"
        rm -fv "$HOME/hashes.txt"
        exit
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done

  # show the hashes.txt version number
  echo "hashes.txt version number: $hash_version_number"

  # show the downloaded version number
  echo "downloaded version number: $download_version_number"

  # ask the user to confirm the versions match
  while true; do
    read -r -p "Do the above versions match? " yn
    case $yn in
      [Yy]* )
        printf "continuing...\n"
        break
        ;;
      [Nn]* )
        echo "cleaning up and exiting script"
        # remove downloaded files - compressed file, extracted file, signing key, and hash file
        rm -fv "$HOME/linux64"
        rm -rfv "$HOME/monero/$download_full_version"
        rm -fv "$HOME/binaryfate.asc"
        rm -fv "$HOME/hashes.txt"
        exit
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done
fi


## finalize the installation ##
# stop the monerod node service
echo "stopping monerod.service"
systemctl --user stop monerod.service

# wait for service to fully stop
echo "waiting 30 seconds for the service to fully stop"
secs=30
while [ $secs -gt 0 ]; do
  echo -ne "$secs\033[0K\r"
  sleep 1
  : $((secs--))
done

# rename the current node version from "current" to "previous" and move the *.current version file if a current version is installed
if [ "$current_version_installed" == true ]; then
  echo "renaming the current version in case something goes wrong"
  mv -fv "$HOME/monero/current" "$HOME/monero/previous"
  mv -fv "$HOME/monero/"*.current "$HOME/monero/previous/"
fi

# create current version file using the name of the downloaded version number
echo "creating current version file"
touch "$HOME/monero/$download_full_version.current"

# rename extracted folder to current
echo "renaming the extracted folder from $download_full_version to current"
mv -fv "$HOME/monero/$download_full_version" "$HOME/monero/current"

# start node service
echo "starting the monerod service"
systemctl --user start monerod.service

# wait for service to fully start
echo "waiting 30 seconds for the service to fully start"
secs=30
while [ $secs -gt 0 ]; do
  echo -ne "$secs\033[0K\r"
  sleep 1
  : $((secs--))
done

# check the status of the service
echo "checking the status of the monerod service"
if systemctl --user is-active --quiet monerod.service; then
  # if the service is running, continue
  echo "the service is running. calling this a success. continuing..."
else
  # if the service is not running, ask if the user wants to manually verify the service
  printf "the service appears not to be running\n"
  while true; do
    read -r -p "Do you want to verify the service manually? " yn
    case $yn in
      [Yy]* )
        printf "continuing...\n"
        break
        ;;
      [Nn]* )
        echo "cleaning up and exiting script"
        # remove downloaded files - compressed file, extracted file, signing key, and hash file
        rm -fv "$HOME/linux64"
        rm -fv "$HOME/binaryfate.asc"
        rm -fv "$HOME/hashes.txt"
        exit
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done

  # show the current status
  systemctl --user status monerod.service

  # ask the user to confirm if the service is running
  while true; do
    read -r -p "Was the service running? " yn
    case $yn in
      [Yy]* )
        printf "continuing...\n"
        break
        ;;
      [Nn]* )
        if [ "$current_version_installed" == true ]; then
          while true; do
            read -r -p "Would you like to roll back the changes?? " yn
            case $yn in
              [Yy]* )
                ## rollback changes ##
                printf "rolling back changes\n"

                # make sure the service is actually stopped
                echo "making sure monerod.service is stopped"
                systemctl --user stop monerod.service

                # wait for service to fully stop
                echo "waiting 30 seconds for the service to fully stop"
                secs=30
                while [ $secs -gt 0 ]; do
                  echo -ne "$secs\033[0K\r"
                  sleep 1
                  : $((secs--))
                done

                # remove the new version
                echo "removing the newly downloaded version"
                rm -fv "$HOME/monero/"*.current
                rm -fv -r "$HOME/monero/current/"

                # put the previous version back
                echo "restoring the previous version"
                mv -fv "$HOME/monero/previous/"*.current "$HOME/monero/"
                mv -fv "$HOME/monero/previous" "$HOME/monero/current"

                # start node service
                echo "starting the previous monerod service"
                systemctl --user start monerod.service

                # wait for service to fully start
                echo "waiting 30 seconds for the service to fully start"
                secs=30
                while [ $secs -gt 0 ]; do
                  echo -ne "$secs\033[0K\r"
                  sleep 1
                  : $((secs--))
                done

                # check the status of the service
                echo "checking the status of the previous monerod service"
                if systemctl --user is-active --quiet monerod.service; then
                  # if the service is running, continue
                  echo "the service is running. calling this a success. continuing..."
                else
                  # if the service is not running, ask if the user wants to manually verify the service
                  printf "the service appears not to be running\n"
                  while true; do
                    read -r -p "Do you want to verify the service manually? " yn
                    case $yn in
                      [Yy]* )
                        printf "continuing...\n"
                        break
                        ;;
                      [Nn]* )
                        echo "cleaning up and exiting script"
                        # remove downloaded files - compressed file, extracted file, signing key, and hash file
                        rm -fv "$HOME/linux64"
                        rm -fv "$HOME/binaryfate.asc"
                        rm -fv "$HOME/hashes.txt"
                        exit
                        ;;
                      * )
                        echo "Please answer yes or no."
                        ;;
                    esac
                  done

                  # show the current status
                  systemctl --user status monerod.service

                  # ask the user to confirm if the service is running
                  while true; do
                    read -r -p "Was the service running? " yn
                    case $yn in
                      [Yy]* )
                        printf "continuing...\n"
                        break
                        ;;
                      [Nn]* )
                        echo "you've got major problems. cleaning up and exiting script"
                        # remove downloaded files - compressed file, extracted file, signing key, and hash file
                        rm -fv "$HOME/linux64"
                        rm -fv "$HOME/binaryfate.asc"
                        rm -fv "$HOME/hashes.txt"
                        exit
                        ;;
                      * )
                        echo "Please answer yes or no."
                        ;;
                    esac
                  done
                fi
                # remove downloaded files - compressed file, extracted file, signing key, and hash file
                rm -fv "$HOME/linux64"
                rm -fv "$HOME/binaryfate.asc"
                rm -fv "$HOME/hashes.txt"
                exit
                ;;
              [Nn]* )
                printf "continuing...\n"
                break
                ;;
              * )
                echo "Please answer yes or no."
                ;;
            esac
          done
        fi
        echo "cleaning up and exiting script"
        # remove downloaded files - compressed file, extracted file, signing key, and hash file
        rm -fv "$HOME/linux64"
        rm -fv "$HOME/binaryfate.asc"
        rm -fv "$HOME/hashes.txt"
        exit
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done
fi


## cleaning up ##
# remove downloaded files - compressed file, signing key, and hash file
echo "removing files that are no longer needed"
rm -fv "$HOME/linux64"
rm -fv "$HOME/binaryfate.asc"
rm -fv "$HOME/hashes.txt"

# remove previous version
if [ -d "$HOME/monero/previous" ]; then
  echo "removing the previous version"
  rm -fv -r "$HOME/monero/previous"
fi

echo "installation complete"
