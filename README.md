# Deploy data-sport distribute device.

[English](README.md) | [繁體中文](README.zh_TW.md)

## System requirements

- Operating system
    - Ubuntu 20.04
- Hardware requirements
    - 2 vCPU
    - 8 GB RAM
    - 60 GB disk space (SSD recommended)

### Before we start...

We should prepare the info we need to deploy the data-sport distribute device.

- [ ] The IP address of the server (e.g. 61.67.2.30)
- [ ] The account and password of the server (not root but have sudo permission) (e.g. sport-user)
- [ ] Register account on https://www.data-sports.tw/#/SportData/Register, and login to change password

## Installation

### Step 1. Download deployment program and install docker and other system packages
- Fetching the latest version of the deployment program

```shell
git clone https://github.com/iii-org/data-sports-distribute-deploy.git
```
### Step 2. Run the deployment program

> This step will take a few minutes to complete.

In this step, we will run the setup script, and automatically install distribute device.
To run the script, make sure you are in the project root directory, and run the following command
```shell
cd ~/distribute-deploy/ 
./setup.sh
```

If any error occurs, it will show the message starting with `[ERROR]` and exit the script.
If the script runs successfully, it will show the message below

```
[INFO] You can visit http://<IP_ADDRESS> to login
[NOTICE] Script executed successfully
```

Then You can visit the  `http://<IP_ADDRESS>` to check if the data-sport distribute device has been deployed successfully.


## Upgrade

Run `script/upgrade.sh` to upgrade the  data-sport distribute device.  
The script will automatically pull the latest code from the repository and run the deployment program.

