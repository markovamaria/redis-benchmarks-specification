#!/bin/bash -x
if [ "$1" = "" ]
then 
    echo "1st param - server or client"
    exit
fi

if [ $1 = 'client' ] || [ $1 = 'all' ] && [ "$2" = "" ]
then 
    echo "2st param - redis-benchmarks version, e.g. 68"
    exit
fi


sudo apt-get update
sudo apt update
sudo apt-get install iperf
#supervisorctl stop 


if [ $1 = 'client' ] || [ $1 = 'all' ]
then 
    export BENCH_VERS=$2
    sudo DEBIAN_FRONTEND=noninteractive apt install python3.10-full
    sudo apt install python3.10-venv
    python3.10 -m venv env$BENCH_VERS
    source env$BENCH_VERS/bin/activate #- working in this environment.

    sudo DEBIAN_FRONTEND=noninteractive apt install docker.io -y
    #sudo apt install supervisor -y
    pip3 install -r req.txt
    # get latest or from master ( pip install git+https://github.com/redis/redis-benchmarks-specification.git)
    pip3 install redis-benchmarks-specification==0.1.$BENCH_VERS # on fixed on July 6
    pip install pandas
    
    sudo groupadd docker # required on NEW host
    sudo usermod -aG docker $USER
    
    ls env$BENCH_VERS/bin/activate
fi

if [ $1 = 'server' ] || [ $1 = 'all' ]
then 
    sudo apt install pkg-config
    sudo apt install make
    sudo apt install numactl
    sudo apt install net-tools

    # install compilers:
    echo --- Instal GCC compiler ---
    sudo apt install gcc
    gcc --version
fi


echo --- Installation is finished, rebooting ... --
sudo reboot

