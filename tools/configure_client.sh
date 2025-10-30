#!/bin/bash -x

echo "All required installations for Clinet or common Client-Server hosts "
echo "1st param - redis-benchmarks version, e.g. 72"

if [ $1 = "" ]
then 
    echo "1st param is missing"
    exit
else
    export BENCH_VERS=$1
fi


sudo apt-get update
sudo apt update
sudo apt-get install iperf
#supervisorctl stop 

sudo DEBIAN_FRONTEND=noninteractive apt install python3.11-full -y
sudo apt install python3.11-venv
python3.11 -m venv env$BENCH_VERS
source env$BENCH_VERS/bin/activate #- working in this environment.

sudo DEBIAN_FRONTEND=noninteractive apt install docker.io -y
#sudo apt install supervisor -y
pip3 install -r req.txt
# get latest or from master ( pip install git+https://github.com/redis/redis-benchmarks-specification.git)
pip3 install redis-benchmarks-specification==$BENCH_VERS # on fixed on July 6
pip install pandas

sudo groupadd docker # required on NEW host
sudo usermod -aG docker $USER

ls env$BENCH_VERS/bin/activate

echo --- Installation is finished, rebooting ... --
sudo reboot

