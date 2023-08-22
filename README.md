# To run the Data Sport client device.
Before start data-sport device, You've to register account on https://www.data-sports.tw/#/SportData/Register, and login after register the account. If register success, You can execute the following command.

First you've to clone the project on your desktop
1. `$ git clone http://gitlab-devops.data-sports.org/root/sport-data-api.git`
After that,  run the set.up script to install the client device
2. `$ cd ~/distribute-deploy/`
3. `$ ./setup.sh`

After that, data-sport client will automatically install 

# Update client device version
1. `$ docker compose down -v` # If docker compose doesn't work, try docker-comsose down -v to shutdown the client service. 
2. `$ git pull origin  http://gitlab-devops.data-sports.org/root/sport-data-api.git`
3. `$ cd ~/distribute-deploy/scripts/`
4. `$ ./upgrade.sh`
