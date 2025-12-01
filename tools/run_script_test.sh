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
    echo "2nd param - redis-benchmarks version, e.g. 0.1.68"
    exit
fi
if [ "$4" = "" ]
then 
    echo "3rd param - Num of runs, e.g. 5"
    exit
fi

if [ "$5" = ""]
then
    echo 5th param - commit in format '1f76bb1'
    exit
fi

if [ "$6" = "" ]
then
    echo 6th param - test name, e.g. 'memtier_benchmark-1key-set-2M-elements-sadd-increasing'
    exit
fi

export HOMEWD=$PWD
export COMP=$1
export OPTION=$2
export COMMIT=$5
export EXP_BUILD="$COMP"_"$OPTION"_"$COMMIT"

export BENCH_VERS=$3
export N=$4
export TEST_NAME=$6

# Optional 7th parameter for perf profiling
USE_PERF="$7"

source env$BENCH_VERS/bin/activate
which python
# ------------ run server ------------
mkdir -p run_server_logs
chmod +x ./r_servers/*
if [ "$USE_PERF" = "perf" ]
then
    perf record -o run_server_logs/perf_$EXP_BUILD.data -g numactl --physcpubind=1 ./r_servers/redis-server_$EXP_BUILD --protected-mode no --port 6379 --dir run_server_logs --logfile run_server_$EXP_BUILD.log --save "" &
else
    numactl --physcpubind=1 ./r_servers/redis-server_$EXP_BUILD --protected-mode no --port 6379 --dir run_server_logs --logfile run_server_$EXP_BUILD.log --save "" &
fi
server_pid=$!
sleep 1

# ------------ run client ------------
source env$BENCH_VERS/bin/activate 

export EXP_RUNS=runs_$EXP_BUILD
mkdir $EXP_RUNS
cd $EXP_RUNS

which redis-benchmarks-spec-client-runner 

for i in $(eval echo "{1..$N}")
do
    echo $i
    redis-benchmarks-spec-client-runner --db_server_host localhost --db_server_port 6379 --test ${TEST_NAME}.yml --client_aggregated_results_folder ./run_"$i" --flushall_on_every_test_start --flushall_on_every_test_end |& tee -a client_runs_"$EXP_RUNS".log
done
kill -9 $server_pid >> kill__$EXP_BUILD.log

# ------------ generate perf report if enabled ------------
if [ "$USE_PERF" = "perf" ]
then
    perf report -i run_server_logs/perf_$EXP_BUILD.data --stdio > run_server_logs/perf_report_$EXP_BUILD.txt
fi

cd $HOMEWD
python get_results.py -e $EXP_BUILD -r $N -t $TEST_NAME

