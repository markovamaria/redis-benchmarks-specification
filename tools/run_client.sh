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

if [ "$3" = "" ]
then 
    echo "3rd param - redis-benchmarks version, e.g. 0.1.68"
    exit
fi

if [ "$4" = "" ]
then 
    echo "4rd param - Num of runs, e.g. 5"
    exit
fi

if [ "$5" = "" ]
then 
    echo "5th param - server ip"
    exit
fi

export HOMEWD=$PWD
export COMP=$1
export OPTION=$2
export EXP_BUILD="$COMP"_"$OPTION"
export BENCH_VERS=$3
export N=$4
export server_ip=$5

# Optional 6th parameter for test name
if [ "$6" != "" ]
then
    export TEST_NAME=$6
fi

# ------------ run client ------------
source env$BENCH_VERS/bin/activate 

export EXP_RUNS=runs_$EXP_BUILD
mkdir $EXP_RUNS
cd $EXP_RUNS

which redis-benchmarks-spec-client-runner 

for i in $(eval echo "{1..$N}")
do
    echo $i
    if [ "$TEST_NAME" != "" ]
    then
        redis-benchmarks-spec-client-runner --db_server_host $server_ip --db_server_port 6379 --test ${TEST_NAME}.yml --client_aggregated_results_folder ./run_"$i" --flushall_on_every_test_start --flushall_on_every_test_end |& tee -a client_runs_"$EXP_RUNS".log
    else
        redis-benchmarks-spec-client-runner --db_server_host $server_ip --db_server_port 6379 --client_aggregated_results_folder ./run_"$i" --flushall_on_every_test_start --flushall_on_every_test_end |& tee -a client_runs_"$EXP_RUNS".log
    fi
done


cd $HOMEWD
if [ "$TEST_NAME" != "" ]
then
    python get_results.py -e $EXP_BUILD -r $N -t $TEST_NAME
else
    python get_results.py -e $EXP_BUILD -r $N
fi

