# monero-node

A script to set up and maintain a private monero node

## This script is provided as is with no guarantees - use at your own risk

### **The script will not run as root or with sudo**

It is highly recommended not to modify it to run with elevated privileges as I cannot guarantee it will work, and because it is safer and more secure to run the monerod service without elevated privileges

The script will create create a systemd user service and enable lingering to ensure the service starts at boot.

- The first run of the script will install the node and set up the config file and service
- The script can be run subsequent times to update the node.
  - If the config file has been modified it will not be overwritten.
  - If the service has been modified it will not be overwritten.

---

## Instructions

### Installing a new node

The script requires no modifications to work. You can just run it with the following command:

> ./update-monero-node.sh

### Updating a node

If you are updating and existing node that you did not install with the script, and you haven't upgraded it to be compatible yet, you need to follow the directions for [Upgrading an existing node](#upgrading-an-existing-node)

If you installed the node with the script, you can just run the same command as you did when you installed it:

> ./update-monero-node.sh

### Defaults

By default the script will install monerod to `~/monero` and set it to use `~/.bitmonero` as the data directory

### Changing the defaults

There are variables you can change at the top of the script that will let you customize the installation. As mentioned previously, it is not necessary to change any variables for the script to work. However, if you already have a different data folder or config file you want to use and you don't want to move them to match the defaults, you can change the defaults to match them.

**WARNING:** Many of the defaults can and will break the script or introduce security risks if you do not know what you are doing, so modify them at your own peril.

The variables can be used to control the configuration file settings if you would rather not use the defaults which are geared towards generating a private remote node.

### Upgrading an existing node

If you have an existing node you would like to modify to use this script, you may want to keep the existing downloaded data so you need to wait for the new node to sync from scratch. The easiest way to do that is to just copy the `lmdb` folder to the data directory the script is set to use.
You need to make sure the node is not running before copying the data - it is recommended to put your existing data in place before running the script for the first time.

You will also want to disable any automatic starting of your existing node before continuing just to make sure you aren't running two instances.

For the config file, I recommend making a note of your settings and then changing the script variables to match so that it generates a new file rather than using your existing one.

Once you've done all of that you can follow the directions for [Installing a new node](#installing-a-new-node)
