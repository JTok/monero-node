# monero-node

A script to set up and update a private monero node

The script has been tested on Ubuntu 20.04.
It will create create a systemd user service and enable lingering to ensure the service starts at boot.

The script can be run subsequent times to update the node. If the bitmonero.conf file has been modified it will not be overwritten.
