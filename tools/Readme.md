## Tips for scripts usage:

### Download last repo version, choose 'tools' branch
```bash
    git clone https://github.com/markovamaria/redis-benchmarks-specification.git --branch tools redis_bench_fork && cd redis_bench_fork/tools
```

### Option 1 : "server" and "client" is the same host. Includes environment preparation, build and run steps.
```bash
    ./env_settings.sh all 72 |& tee env_all_72.log
```

* params:
  * all - type "client and server"
  * 72 - redis-benchmarks-specification version

```bash
    cd redis_bench_fork/tools && ./build_script.sh gcc default AWS 6bf9b14 |& tee build_gcc_default_6bf9b14.log
    ./run_script.sh gcc default 72 3 6bf9b14 |& tee run_script_gcc_default_6bf9b14.log
```

* params:
  * default - option to compile redis
  * gcc - compiler to compile redis
  * 72 - as above
  * 3 - number of runs
  * 6bf9b14 - redis version to test 

### Option 2: "server" and "client" are different hosts:

#### Part 1: "server" part - prepare environment, build redis server, run server 

```bash
    ./env_settings.sh server 72 |& tee env_server_72.log
```
* params:
  * server - type for "client" specific environment
  * 72 - redis-benchmarks-specification version

```bash
    cd redis_bench_fork/tools && ./build_script.sh gcc default AWS 6bf9b14 |& tee build_gcc_default_6bf9b14.log
    ./run_server.sh gcc default 6bf9b14 |& tee run_server_gcc_default_6bf9b14.log
```
* build params:
  * gcc - compiler to compile redis
  * default - option to compile redis
  * AWS or BM (bare metal) - AWS mean that host has an internet access, BM - there is no internet access (local infra preparation)
  * 6bf9b14 - redis version to test 

* run params:
  * default - option to compile redis
  * gcc - compiler to compile redis
  * 6bf9b14 - redis version to test 

#### Part 2: "Client" part - prepare environment, run client (server should be run in parallel already)

```bash
    ./env_settings.sh client 72 |& tee env_client_72.log
```
* params:
  * client - type for "client" specific environment
  * 72 - redis-benchmarks-specification version

```bash
    cd redis_bench_fork/tools && ./run_client.sh gcc default 72 5 INT_IP |& tee run_client_gcc_default_6bf9b14.log
```

* params:
  * gcc - compiler to compile redis
  * default - option to compile redis
  * 5 - number of runs
  * 72 - redis-benchmarks-specification version
  * INT_IP - ip of server (internal IP for GCP, private IP for AWS)
