#!/bin/bash -x

if [ "$1" = "" ] 
then 
    echo 1st param - compiler name, like 'gcc' / 'icx' / 'icc' / 'gcc-11' / 'clang-14'
    exit
fi

if [ "$2" = "" ]
then 
    echo 2nd param - experiment name, like 'default' / 'O3_flto' / 'O3_flto_deps' / 'O3' / 'O3_deps' / 'fno_plt'
    exit
fi

export HOMEWD=$PWD
export COMP=$1
export OPTION=$2
export EXP_BUILD="$COMP"_"$OPTION"

# ------------ run server ------------
mkdir -p run_server_logs
chmod +x ./r_servers/*
numactl --physcpubind=1 ./r_servers/redis-server_$EXP_BUILD --protected-mode no --port 6379 --dir run_server_logs --logfile run_server_$EXP_BUILD.log --save "" &
server_pid=$!
echo $server_pid > server_pid