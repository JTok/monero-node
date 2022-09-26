#!/bin/bash

# author: jtok
# version: v1.1.0 - 2022.09.25
# url: https://github.com/JTok/monero-node/tags
# description: This script will update your monero node to the latest version, or install it if it isn't installed yet


#### DISCLAIMER ####
# Use at your own risk. This is a work-in-progress and provided as is.
# I have tested this as best as I am able, but YMMV.


###################################################### variables start ######################################################

#### instructions ####
## most users will not need to change any variables from the defaults ##
# you can set the variables below to your liking, or leave them as is, the script will work without any changes
# if you do make changes, all paths need to be writeable by the user running this script
# this script will not run as root or sudo, so please run it as a standard user without sudo
# be very careful when changing the variables below, as you can break the script or create a security risk


#### paranoia modes ####
## these modes will ignore some of the variables below in oder to allow for more user input ##

# Paranoid mode - use this if you really don't want to trust the script to verify downloaded files for you
paranoid_mode=false

# Ultra paranoid mode - the same as Paranoid mode, but also requires you to manually download files
ultra_paranoid_mode=false


#### standard variables #####

# installation directory
install_dir="$HOME/monero"

# data directory
data_dir="$HOME/.bitmonero"

# config file path
config_file="$data_dir/bitmonero.conf"

# download directory for storing downloaded files temporarily during install
download_dir="/tmp/monero-node"

#### advanced variables ####

## monerod service options ##
# systemd user services directory
# DO NOT CHANGE THIS UNLESS YOU KNOW WHAT YOU ARE DOING
systemd_user_services_dir="$HOME/.config/systemd/user"

# monero service name
monero_service_name="monerod.service"

# monero service file path
monero_service_file="$systemd_user_services_dir/$monero_service_name"

# pid file path
pid_file="$data_dir/bitmonero.pid"


## config file options ##
# rpc bind ip - leave default to bind to all interfaces
rpc_bind_ip="0.0.0.0"

# rpc bind port
rpc_bind_port="18081"


#### danger zone ####
## don't change these unless you know what you're doing ##
## changing these could break the script or make the installation not work correctly ##

## installation options ##
# current version directory name
current_version_dir_name="current"

# current version directory path
current_version_dir="$install_dir/$current_version_dir_name"

# previous version directory name
previous_version_dir_name="previous"

# previous version directory path
previous_version_dir="$install_dir/$previous_version_dir_name"

## monero daemon options ##
# monero node options
monero_node_options="--config-file=$config_file --detach --pidfile $pid_file"

# monero node binary name
monero_node_binary_name="monerod"

# monero node binary path
monero_node_binary="$current_version_dir/$monero_node_binary_name"

## download options ##
# monero node download url
monero_node_download_url="https://downloads.getmonero.org/cli/linux64"

# monero download file name
monero_download_file_name="linux64"

# monero download file path
monero_download_file="$download_dir/$monero_download_file_name"

# downloaded monero file is compressed
monero_download_file_compressed=true

# binaryfate signing key url
binaryfate_signing_key_url="https://raw.githubusercontent.com/monero-project/monero/master/utils/gpg_keys/binaryfate.asc"

# binaryfate download file name
binaryfate_download_file_name="binaryfate.asc"

# binaryfate download file path
binaryfate_download_file="$download_dir/$binaryfate_download_file_name"

# hashes.txt url
hashes_txt_url="https://www.getmonero.org/downloads/hashes.txt"

# hashes.txt file name
hashes_txt_file_name="hashes.txt"

# hashes.txt file path
hashes_txt_file="$download_dir/$hashes_txt_file_name"


## config file options ##
# monero daemon log file path
monero_daemon_log_file="/var/log/monero/monerod.log"

# monero daemon max log file size
# leave as 0 to prevent monerod from managing the log files and instead let logrotate take care of it
monero_daemon_max_log_file_size=0

# p2p bind ip - leave default to bind to all interfaces
p2p_bind_ip="0.0.0.0"

# p2p bind port
p2p_bind_port="18080"

# hide my port - leave default to prevent nodes from spreading your IP to other nodes
hide_my_port=1

# confirm external bind - leave default to allow external connections to use unsafe RPC calls
confirm_external_bind=1

# restricted rpc - leave default to prevent unsafe RPC calls
restricted_rpc=1

# no-igd - leave default to keep UPnP port mapping disabled
no_igd=1

# db safe sync mode - if enabled db writes will be slower, but more reliable
db_safe_sync_mode=false

# enforce dns checkpointing - emergency checkpoints set by MoneroPulse operators will be enforced to workaround potential consensus bugs
# Check https://monerodocs.org/infrastructure/monero-pulse/ for explanation and trade-offs
enforce_dns_checkpointing=1

# out peers - This will enable much faster sync and tx awareness; the default 8 is suboptimal nowadays
out_peers=64

# in peers - The default is unlimited; we prefer to put a cap on this
in_peers=1024

# limit rate up - 10240 kB/s == 10MB/s; a raise from default 2048 kB/s; contribute more to p2p network
limit_rate_up=10240

# limit rate down - 1048576 kB/s == 1GB/s; a raise from default 8192 kB/s; allow for faster initial sync
limit_rate_down=1048576

# WARNING: setting a username and password in the script will introduce security risks
# if these are not filled in, the script will prompt you for them when it is run
# rpc username to use for the monero service
username=""
# rpc password to use for monero service
password=""

## cryptographic options ##
# expected binaryfate signing key fingerprint
expected_key='pub   rsa4096/F0AF4D462A0BDF92 2019-12-12 [SCEA]
      Key fingerprint = 81AC 591F E9C4 B65C 5806  AFC3 F0AF 4D46 2A0B DF92
uid                           binaryFate <binaryfate@getmonero.org>
sub   rsa4096/2593838EABB1F655 2019-12-12 [SEA]'

# expected hashes.txt signature
expected_hashes_signature='gpg:                using RSA key 81AC591FE9C4B65C5806AFC3F0AF4D462A0BDF92
gpg: Good signature from "binaryFate <binaryfate@getmonero.org>" [unknown]
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: 81AC 591F E9C4 B65C 5806  AFC3 F0AF 4D46 2A0B DF92'


###################################################### variables end ######################################################


##################################################### fucntions start #####################################################

# function to clean up
function cleanup() {
  # set local variables
  local is_rollback_=$1
  local extracted_download_dir_=$2

  # check if is_rollback_ is empty, if so set it to false
  if [ -z "$is_rollback_" ]; then
    is_rollback_=false
  fi

  # perform rollback tasks if is_rollback_ is true
  if [ "$is_rollback_" = true ]; then
    # make sure the service is actually stopped
    echo "making absolutely sure $monero_service_name is stopped"
    systemctl --user stop "$monero_service_name"

    # wait for service to fully stop
    echo "waiting 30 seconds for the service to fully stop"
    secs=30
    while [ $secs -gt 0 ]; do
      echo -ne "$secs\033[0K\r"
      sleep 1
      : $((secs--))
    done

    # remove new current version file if it exists
    for f in "$install_dir"/*.current; do
      if [ -f "$f" ]; then
        echo "Removing new current version file $f"
        rm -rfv "$f"
      fi
    done
    # remove new current version directory if it exists
    if [ -d "$current_version_dir" ]; then
      echo "Removing new current version directory"
      rm -rfv "$current_version_dir"
    fi

    # put the previous version back if it exists
    if [ -d "$previous_version_dir" ]; then
      echo "Putting previous version file back"
      mv -fv "$previous_version_dir/"*.current "$install_dir/"
      echo "Putting previous version directory back"
      mv -fv "$previous_version_dir" "$current_version_dir"
    fi
  fi

  # remove binaryfate signing key if it exists
  if [ -f "$binaryfate_download_file" ]; then
    echo "removing $binaryfate_download_file_name file"
    rm -fv "$binaryfate_download_file"
  fi

  # remove hashes.txt if it exists
  if [ -f "$hashes_txt_file" ]; then
    echo "removing $hashes_txt_file_name file"
    rm -fv "$hashes_txt_file"
  fi

  # remove downloaded monero file if it exists
  if [ -f "$monero_download_file" ]; then
    echo "removing $monero_download_file_name file"
    rm -fv "$monero_download_file"
  fi

  # remove extracted monero directory if it exists and the variable has been passed
  if [ -n "$extracted_download_dir_" ] && [ -d "$download_dir/$extracted_download_dir_" ]; then
    echo "removing $extracted_download_dir_ directory"
    rm -rfv "${download_dir:?}/$extracted_download_dir_"
  fi

  # remove download directory and its contents if it is in /tmp and if it exists
  # we don't want to remove this directory if it is not in /tmp because it may contain other files
  if [ -d "$download_dir" ] && [[ "$download_dir/" = "/tmp/"* ]]; then
    echo "removing $download_dir directory"
    rm -rfv "$download_dir"
  fi

  # remove previous version directory if it exists
  if [ -d "$previous_version_dir" ]; then
    echo "removing $previous_version_dir directory"
    rm -rfv "$previous_version_dir"
  fi
}

# function to see if the user would like to continue or abort
function continue_or_abort() {
  # set local variables
  local is_rollback_=$1
  local extracted_download_dir_=$2

  # check if is_rollback_ is empty, if so set it to false
  if [ -z "$is_rollback_" ]; then
    is_rollback_=false
  fi

  while true; do
    read -r -p "Choose C to continue anyway, or A to abort " ca
    case $ca in
      [Cc]* )
        printf "continuing...\n"
        break
        ;;
      [Aa]* )
        echo "cleaning up and aborting script"
        # run cleanup function
        if [ -z "$extracted_download_dir_" ]; then
          cleanup "$is_rollback_"
        else
          cleanup "$is_rollback_" "$extracted_download_dir_"
        fi
        exit 1
        ;;
      * )
        echo "You must choose C to continue anyway, or A to abort"
        ;;
    esac
  done
}


###################################################### fucntions end ######################################################


###################################################### script start ######################################################


## pre-script checks ##

# check if the script is running as root and exit if it is
if [[ $EUID -eq 0 ]]; then
  echo "This script cannot be run as root or with sudo. Please re-run it as your regular user."
  exit 1
fi

# check if the install directory exists and create it if it doesn't
if [[ ! -d "$install_dir" ]]; then
  mkdir -p "$install_dir"
fi
# verify that the install directory is writable and exit if it isn't
if [[ ! -w "$install_dir" ]]; then
  echo "The install directory is not writable. aborting script"
  exit 1
fi

# check if the data directory exists and create it if it doesn't
if [[ ! -d "$data_dir" ]]; then
  mkdir -p "$data_dir"
fi
# verify that the data directory is writable and exit if it isn't
if [[ ! -w "$data_dir" ]]; then
  echo "The data directory is not writable. aborting script"
  exit 1
fi

# check if the download directory exists and create it if it doesn't; if it does, remove all contents
if [ ! -d "$download_dir/" ]; then
  echo "creating download directory"
  mkdir -p "$download_dir"
else
  echo "download directory already exists, ensuring it is empty"
  # check to see if the download directory contains any other directories or files
  if [ "$(ls -A $download_dir)" ]; then
    echo "download directory is not empty, verifying that it is in /tmp"
    # check to see if the download directory is in /tmp
    if [ -d "$download_dir" ] && [[ "$download_dir/" = "/tmp/"* ]]; then
      echo "download directory is in /tmp, it is save to remove all contents"
      rm -rfv "${download_dir:?}"/*
    else
      echo "download directory is not in /tmp and contains files. it is unsafe to delete them, aborting script"
      exit 1
    fi
  fi
fi
# verify that the download directory is writable
if [ ! -w "$download_dir/" ]; then
  echo "download directory is not writable, aborting script"
  exit 1
fi

# check if the systemd user services directory exists and create it if it doesn't
if [ ! -d "$systemd_user_services_dir/" ]; then
  echo "creating systemd user services directory"
  mkdir -p "$systemd_user_services_dir"
fi
# verify that the systemd user services directory is writable
if [ ! -w "$systemd_user_services_dir/" ]; then
  echo "systemd user services directory is not writable, aborting script"
  exit 1
fi

# check to see if their is a current version of monero installed
if [ -d "$current_version_dir/" ]; then
  current_version_installed=true
else
  current_version_installed=false
fi


## set up the monero service ##

# check if the monero service already exists.
echo "checking if $monero_service_name already exists"
if systemctl --user list-units --full -all | grep -Fq "$monero_service_name"; then
  echo "$monero_service_name already exists, so no need to recreate it"
else
  echo "$monero_service_name does not exist, so creating it now"

  # enable linger so that the service will start at boot before the user logs in
  echo "enabling lingering for current user so that the service will start at boot"
  loginctl enable-linger "$USER"

  # create the service file
  echo "creating $monero_service_name file"
  echo "[Unit]
Description=monerod service running as $monero_service_name
After=network.target

[Service]
Type=forking
PIDFile=$pid_file
ExecStart=$monero_node_binary $monero_node_options

[Install]
WantedBy=default.target
" > "$monero_service_file"

  # enable the service and reload the daemons so systemd will see it
  echo "enabling the service and reloading daemons"
  systemctl --user enable "$monero_service_name"
  systemctl --user daemon-reload

  # check to make sure the service was created successfully before continuing
  echo "checking if $monero_service_name installed successfully"
  if systemctl --user list-units --full -all | grep -Fq "$monero_service_name"; then
    echo "$monero_service_name installed successfully. continuing..."
  else
    echo "$monero_service_name failed to install. aborting script"
    exit 1
  fi

fi


## set up the config file ##

# check if config file already exists
echo "checking if $config_file already exists"
if [[ -f "$config_file" ]]; then
  echo "$config_file exists. so no need to recreate it"
else
  echo "$config_file does not exist. creating file."

  # check if the username and password variables are set already
  if [[ -z "$username" ]] || [[ -z "$password" ]]; then
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

    echo "Thank you. $config_file will have an rpc login username of: $username"
  fi

  # write the config file
  echo "creating $config_file"
  echo "# $config_file

# Data directory (blockchain db and indices)
data-dir=$data_dir

# Log file
log-file=$monero_daemon_log_file
max-log-file-size=$monero_daemon_max_log_file_size            # Prevent monerod from managing the log files; we want logrotate to take care of that

# P2P full node
#p2p-bind-ip=$p2p_bind_ip             # Bind to all interfaces (the default)
#p2p-bind-port=$p2p_bind_port             # Bind to default port
hide-my-port=$hide_my_port                  # prevents nodes from spreading your IP to other nodes

# RPC open node
rpc-bind-ip=$rpc_bind_ip             # Bind to all interfaces
rpc-bind-port=$rpc_bind_port             # Bind on default port
confirm-external-bind=$confirm_external_bind         # Open node (confirm)
restricted-rpc=$restricted_rpc                # Prevent unsafe RPC calls
no-igd=$no_igd                        # Disable UPnP port mapping

# Slow but reliable db writes
#db-sync-mode=safe

# Emergency checkpoints set by MoneroPulse operators will be enforced to workaround potential consensus bugs
# Check https://monerodocs.org/infrastructure/monero-pulse/ for explanation and trade-offs
enforce-dns-checkpointing=$enforce_dns_checkpointing

out-peers=$out_peers              # This will enable much faster sync and tx awareness; the default 8 is suboptimal nowadays
in-peers=$in_peers             # The default is unlimited; we prefer to put a cap on this

limit-rate-up=$limit_rate_up        # 10240 kB/s == 10MB/s; a raise from default 2048 kB/s; contribute more to p2p network
limit-rate-down=$limit_rate_down   # 1048576 kB/s == 1GB/s; a raise from default 8192 kB/s; allow for faster initial sync

# Set login for daemon
rpc-login=$username:$password
" > "$config_file"

# check variables to see if they are using the default or not. if not, then add them to the config file
# uncomment p2p bind ip if it is not the default
if [[ "$p2p_bind_ip" != "0.0.0.0" ]]; then
  sed -i '/#p2p-bind-ip=$p2p_bind_ip/s/^#//g' "$config_file"
fi

# uncomment p2p bind port if it is not the default
if [[ "$p2p_bind_port" != "18080" ]]; then
  sed -i '/#p2p-bind-port=$p2p_bind_port/s/^#//g' "$config_file"
fi

# uncomment db sync mode if it is not the default
if [[ "$db_safe_sync_mode" != false ]]; then
  sed -i '/#db-sync-mode=safe/s/^#//g' "$config_file"
fi

# get the system's local IP address
ip_address=$(hostname -I | awk '{print $1}')

  echo "To edit the service configuration you can edit $config_file"
  echo "IMPORTANT: the rpc service is running on $ip_address:$rpc_bind_port"
  read -r -p "Note the port above and press any key to continue ..."

  # check if config file was successfully created
  echo "checking if $config_file was created successfully"
  if [[ -f "$config_file" ]]; then
    echo "$config_file successfully created. continuing..."
  else
    echo "$config_file was not successfully created. aborting script"
    exit 1
  fi
fi


## verify the signing key ##

# get the binaryfate signing key
echo "getting the binaryfate signing key and saving it as $binaryfate_download_file_name"
wget -O "$binaryfate_download_file" "$binaryfate_signing_key_url"

# store the downloaded key in a variable
downloaded_key=$(gpg --keyid-format long --with-fingerprint "$binaryfate_download_file")


# compare the expected key and the downloaded key
printf "checking if the downloaded key is what is expected\n"
if [[ "$expected_key" == "$downloaded_key" ]]; then
  # if the keys match continue
  echo "the download key matched the expected key, continuing"
else
  # if the keys do not match, ask if the keys should be compared manually
  printf "the downloaded key did not match the expected key\n"
  printf "please choose continue to compare the keys manually or abort to clean up and exit the script\n"
  continue_or_abort

  # show what the expected signing key is
  printf "the fingerprint should look like this:\n"
  echo "$expected_key"
  printf "\n\n"

  # show the downloaded signing key
  gpg --keyid-format long --with-fingerprint "$binaryfate_download_file"

  # ask the user to confirm the keys match
  while true; do
    read -r -p "Do the above keys match? " yn
    case $yn in
      [Yy]* )
        printf "continuing...\n";
        break
        ;;
      [Nn]* )
        # ask the user if they would like to continue or abort
        continue_or_abort
        break
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done
fi


## verify hashes.txt is authentic ##

# get the hashes.txt file
echo "getting the hashes.txt file and saving it as $hashes_txt_file_name"
wget -O "$hashes_txt_file" "$hashes_txt_url"

# store the downloaded hashes.txt signature in a variable
downloaded_hashes_signature=$(gpg --verify "$hashes_txt_file" 2>&1)
# remove the first line that contains the timestamp
downloaded_hashes_signature=$(sed '1d' <<< "$downloaded_hashes_signature")

# compare the expected signature and the downloaded signature
printf "checking if the signature for %s is what is expected\n" "$hashes_txt_file_name"
if [[ "$expected_hashes_signature" == "$downloaded_hashes_signature" ]]; then
  # if the signatures match continue
  echo "the download signature matched the expected signature, continuing"
else
  # if the signatures do not match, ask if the signatures should be compared manually
  printf "the downloaded signature did not match the expected signature\n"
  printf "please choose continue to compare the signatures manually or abort to clean up and exit the script\n"
  continue_or_abort

  # show what the expected hashes.txt signature is
  printf "you should see the following lines if it is authentic:\n"
  echo "$expected_hashes_signature"
  printf "\n\n"

  # show the downloaded hashes.txt signature
  gpg --verify "$hashes_txt_file"

  # ask the user to confirm the signatures match
  while true; do
    read -r -p "Do the above signatures match? " yn
    case $yn in
      [Yy]* )
        printf "continuing...\n"
        break
        ;;
      [Nn]* )
        # ask the user if they would like to continue or abort
        continue_or_abort
        break
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done
fi


## verify the downloaded copy of monero ##

# download latest version of monero
echo "downloading the latest monero version"
wget -O "$monero_download_file" "$monero_node_download_url"

# store the sha for the new monero version that was downloaded in a variable
monero_download_shasum=$(shasum -a 256 "$monero_download_file" | awk '{print $1}')

# check that the hash for the new monero that was downloaded is in hashes.txt
printf "checking %s for the hash of the new monero file that was downloaded\n" "$hashes_txt_file_name"
if grep -Fq "$monero_download_shasum" "$hashes_txt_file"; then
  # if the hash is found let the user know and display the line
  echo "the hash for the new monero version that was downloaded was found in the following line:"
  # store the output of the grep command in a variable for use later and display it
  hash_shasum_line=$(grep -F "$monero_download_shasum" "$hashes_txt_file")
  echo "$hash_shasum_line"

  # save the version number from the hash before continuing
  # first strip the hash and space from the start of the line the hash was found on in hashes.txt and store it in a variable
  hash_full_version="${hash_shasum_line##* }"
  # second strip the file extension from the end and update the variable
  hash_full_version="${hash_full_version%%.tar.bz2*}"
else
  # if the hash is not found let the user know and exit the script
  printf "the hash for the new monero version that was downloaded was not found. this is so unsafe that the script will not continue\n"
  printf "if you know what you are doing you can enable the bypass for this check, but you could lose everything if you do!\n"
  printf "cleaning files and aborting script\n"
  # run cleanup function
  cleanup
  exit
fi


## extract the new monero version ##

# check to see if the file is expected to be compressed
if [ "$monero_download_file_compressed" = true ]; then
  # extract the new monero version that was downloaded to the monero directory
  echo "extracting the new monero version that was downloaded"
  tar -xvf "$monero_download_file" -C "$download_dir/"
fi


## verify that the current version doesn't match the version number of the extracted download ##

# loop through all the directories and store whatever the last one is in a variable
# (there should only be one directory, so no need to store them as an array and search the array)
for d in "$download_dir"/*; do
  # check to see if the current object in $d is a directory
  if [ -d "$d" ]; then
    # if it is a directory store just the basename, not the full path, in a variable
    download_full_version=$(basename "$d")
  fi
done

# check to make sure the download_full_version variable is not empty
if [ -z "$download_full_version" ]; then
  # if it is empty, let the user know and exit the script
  echo "could not find a directory with the monero files. unrecoverable error. cleaning files and aborting script"
  # run cleanup function
  cleanup
  exit
fi

# check to make sure the monerod binary exists
if [ ! -f "$download_dir/$download_full_version/$monero_node_binary_name" ]; then
  # if it doesn't exist, let the user know and exit the script
  echo "could not find the monerod binary. unrecoverable error. cleaning files and aborting script"
  # run cleanup function
  cleanup false "$download_full_version"
  exit
fi

# compare the current version number to the downloaded version number if a current version exists
if [ "$current_version_installed" == true ]; then
  # store the currently running version in a variable so it can be compared to the downloaded version
  current_full_version=$(find "$install_dir/" -type f -name "*.current")
  # strip the full path and store just the basename
  current_full_version=$(basename "$current_full_version")
  # strip the file extension and store just the version
  current_full_version="${current_full_version%%.current*}"

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
          # ask the user if they would like to continue or abort
          continue_or_abort false "$download_full_version"
          break
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
          echo "cleaning up and aborting script"
          # run cleanup function
          cleanup false "$download_full_version"
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
printf "checking if the %s version number matches the downloaded version number\n" "$hashes_txt_file_name"
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
        # ask the user if they would like to continue or abort
        continue_or_abort false "$download_full_version"
        break
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done

  # show the hashes.txt version number
  echo "$hashes_txt_file_name version number: $hash_version_number"

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
        # ask the user if they would like to continue or abort
        continue_or_abort false "$download_full_version"
        break
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done
fi


## finalize the installation ##

# stop the monerod node service
echo "stopping $monero_service_name"
systemctl --user stop "$monero_service_name"

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
  mv -fv "$current_version_dir" "$previous_version_dir"
  mv -fv "$install_dir/"*.current "$previous_version_dir/"
fi

# create current version file using the name of the downloaded version number
echo "creating current version file"
touch "$install_dir/$download_full_version.current"

# move extracted directory to current directory
echo "renaming the extracted directory from $download_full_version to current"
mv -fv "$download_dir/$download_full_version" "$current_version_dir"

# start node service
echo "starting $monero_service_name"
systemctl --user start "$monero_service_name"

# wait for service to fully start
echo "waiting 30 seconds for the service to fully start"
secs=30
while [ $secs -gt 0 ]; do
  echo -ne "$secs\033[0K\r"
  sleep 1
  : $((secs--))
done

# check the status of the service
echo "checking the status of $monero_service_name"
if systemctl --user is-active --quiet "$monero_service_name"; then
  # if the service is running, continue
  echo "$monero_service_name is running. calling this a success. continuing..."
else
  # if the service is not running, ask if the user wants to manually verify the service
  printf "%s appears not to be running\n" "$monero_service_name"
  while true; do
    read -r -p "Do you want to verify the service manually? " yn
    case $yn in
      [Yy]* )
        printf "continuing...\n"
        break
        ;;
      [Nn]* )
        # ask the user if they would like to continue or abort
        continue_or_abort
        break
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done

  # show the current status
  systemctl --user status "$monero_service_name"

  # ask the user to confirm if the service is running
  while true; do
    read -r -p "Was $monero_service_name running? " yn
    case $yn in
      [Yy]* )
        printf "continuing...\n"
        break
        ;;
      [Nn]* )
        if [ "$current_version_installed" == true ]; then
          while true; do
            read -r -p "Would you like to roll back to the previously installed version? " yn
            case $yn in
              [Yy]* )
                ## rollback changes ##
                printf "rolling back to the previous version and cleaning up\n"
                # run cleanup function
                cleanup true

                # start node service
                echo "starting the previous service, $monero_service_name"
                systemctl --user start "$monero_service_name"

                # wait for service to fully start
                echo "waiting 30 seconds for the service to fully start"
                secs=30
                while [ $secs -gt 0 ]; do
                  echo -ne "$secs\033[0K\r"
                  sleep 1
                  : $((secs--))
                done

                # check the status of the service
                echo "checking the status of the previous service, $monero_service_name"
                if systemctl --user is-active --quiet "$monero_service_name"; then
                  # if the service is running, continue
                  echo "$monero_service_name is running. calling this a success. continuing..."
                else
                  # if the service is not running, ask if the user wants to manually verify the service
                  printf "%s appears not to be running\n" "$monero_service_name"
                  while true; do
                    read -r -p "Do you want to verify $monero_service_name is running manually? " yn
                    case $yn in
                      [Yy]* )
                        printf "continuing...\n"
                        break
                        ;;
                      [Nn]* )
                        # ask the user if they would like to continue or abort
                        continue_or_abort
                        break
                        ;;
                      * )
                        echo "Please answer yes or no."
                        ;;
                    esac
                  done

                  # show the current status
                  systemctl --user status "$monero_service_name"

                  # ask the user to confirm if the service is running
                  while true; do
                    read -r -p "Was $monero_service_name running? " yn
                    case $yn in
                      [Yy]* )
                        printf "continuing...\n"
                        break
                        ;;
                      [Nn]* )
                        # ask the user if they would like to continue or abort
                        continue_or_abort
                        break
                        ;;
                      * )
                        echo "Please answer yes or no."
                        ;;
                    esac
                  done
                fi
                # verifying everything is cleaned up before aborting script by running cleanup function
                cleanup
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
        # ask the user if they would like to continue or abort
        continue_or_abort
        break
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done
fi


## clean up ##

# remove downloaded files - compressed file, signing key, and hash file
echo "cleaning up leftover files"
# run cleanup function
cleanup

echo "installation complete"
echo "if this is a new node, or you have pointed the data into a new directory, it could take several hours to several days to fully sync"

###################################################### script end ######################################################
