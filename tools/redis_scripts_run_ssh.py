import os
import subprocess
import time
import boto3
import string
import signal
import argparse


# read argumnets from command line
parser = argparse.ArgumentParser(description='Run testing on Running Pairs server and client in AWS EC2"')
parser.add_argument('--clean', '-c', action='store_true', help='Clean all previously downloaded folders `redis_bench_fork` on all running clients and servers in AWS fitting to filter', required=False)
parser.add_argument('--bench_version', '-v', type=str, help='Redis benchmark version, e.g. 72 (default)', required=False, default="72")
parser.add_argument('--server_commit', type=str, help='Redis server commit, e.g. 2aad03f (default)', required=False, default="2aad03f")
parser.add_argument('--runs', '-r', type=int, help='Number of runs, e.g. 3 (default)', required=False, default=3)

args = parser.parse_args()

# input parameters
redis_bench_version = args.bench_version
# commit = "6bf9b14" # 29 Jun 2023
commit = args.server_commit # 21 Sept 2023
num_runs = args.runs

ssh_prefix = "ssh ubuntu@{} -i /home/mmarkova/.ssh/Maria_key_disruptor.pem -o StrictHostKeyChecking=no -o 'ProxyCommand=connect-proxy -S proxy-fm.intel.com:1080 %h %p'  -t "
scp_prefix = "scp -i /home/mmarkova/.ssh/Maria_key_disruptor.pem -o StrictHostKeyChecking=no -o 'ProxyCommand=connect-proxy -S proxy-fm.intel.com:1080 %h %p' ubuntu@{}:/home/ubuntu/redis_bench_fork/tools/results_gcc_default.csv {}_results.csv"

ec2 = boto3.resource("ec2")
host_pairs = dict()
instances = ec2.instances.filter(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}])
for instance in instances:
    name = [el['Value'] for el in instance.tags if el['Key'] == 'Name'][0]
    if "maria" in name:
        pair_name = name.split("_")[-1]
        if pair_name not in host_pairs:
            host_pairs[pair_name] = dict()
        if 'client' in name:
            if 'client_name' in host_pairs[pair_name]:
                print("ERROR, multiple clients with same pair # - ", name, "and", host_pairs[pair_name]['client_name'])
            host_pairs[pair_name]["client_name"] = name
            host_pairs[pair_name]['client_type'] = instance.instance_type
            host_pairs[pair_name]['client_dns_name'] = instance.public_dns_name
        else:
            if 'server_name' in host_pairs[pair_name]:
                print("ERROR, multiple servers with same pair # - ", name, "and", host_pairs[pair_name]['server_name'])
            host_pairs[pair_name]['server_name'] = name
            host_pairs[pair_name]['server_type'] = instance.instance_type
            host_pairs[pair_name]['server_dns_name'] = instance.public_dns_name
            host_pairs[pair_name]['server_ip_address'] = instance.private_ip_address

tests = list()
if args.clean:
    for pair_name in host_pairs:
        server = host_pairs[pair_name]['server_dns_name']
        client = host_pairs[pair_name]['client_dns_name']
        status = f"Remove: {pair_name}, server: {server}, client: {client}"
        command = ssh_prefix.format(client) + f"'rm -rf redis_bench_fork && sudo reboot'"
        print('\t' + command)
        out, err = subprocess.Popen(command, shell=True, preexec_fn=os.setsid, stdout=subprocess.PIPE, stderr=subprocess.PIPE).communicate()
        command = ssh_prefix.format(server) + f"'rm -rf redis_bench_fork && sudo reboot'"
        print('\t' + command)
        out, err = subprocess.Popen(command, shell=True, preexec_fn=os.setsid, stdout=subprocess.PIPE, stderr=subprocess.PIPE).communicate()
    exit()

# prepare env
for pair_name in host_pairs:
    server = host_pairs[pair_name]['server_dns_name']
    client = host_pairs[pair_name]['client_dns_name']
    status = f"Init: {pair_name}, server: {server}, client: {client}"
    print(status)
    for c in status:
        if c not in string.printable:
            print("eh")
    server_file = open(pair_name + "_server.log", "w")
    client_file = open(pair_name + "_client.log", "w")
    
    # Install iperf on client, write output to file 
    host_role = "client"
    env_log = "env_" + host_role + "_" + redis_bench_version + ".log"
    command = ssh_prefix.format(client) + f"'git clone https://github.com/markovamaria/redis-benchmarks-specification.git --branch tools redis_bench_fork && cd redis_bench_fork/tools && ./configure_client.sh {redis_bench_version} '"
    print('\t' + command)
    host_pairs[pair_name]["client_proc"] = subprocess.Popen(command, shell=True, preexec_fn=os.setsid, stdout=client_file, stderr=client_file, stdin=subprocess.PIPE)

    # Install iperf on server, write output to file
    host_role = "server"
    env_log = "env_" + host_role + "_" + redis_bench_version + ".log"
    command = ssh_prefix.format(server) + f"'git clone https://github.com/markovamaria/redis-benchmarks-specification.git --branch tools redis_bench_fork && cd redis_bench_fork/tools && ./build_script.sh gcc default AWS {commit} && sudo reboot'"
    print('\t' + command)
    host_pairs[pair_name]["server_proc"] = subprocess.Popen(command, shell=True, preexec_fn=os.setsid, stdout=server_file, stderr=server_file, stdin=subprocess.PIPE)

    # Create dict for storing data
    host_pairs[pair_name]["server_log"] = server_file
    host_pairs[pair_name]["client_log"] = client_file

timeout = 60 * 8
print(f"Waiting for {timeout}s")
time.sleep(timeout)


for pair_name in host_pairs:
    server = host_pairs[pair_name]['server_dns_name']
    client = host_pairs[pair_name]['client_dns_name']

    if host_pairs[pair_name]["server_proc"].poll() is None:
        print(f"Install env process is not finished for server {pair_name}. Killing ...")
        #host_pairs[pair_name]["server_proc"].kill()
        os.killpg(os.getpgid(host_pairs[pair_name]["server_proc"].pid), signal.SIGTERM)
        continue
    if host_pairs[pair_name]["client_proc"].poll() is None:
        print(f"Install env process is not finished for client {pair_name}. Killing ...")
        #host_pairs[pair_name]["client_proc"].kill()
        os.killpg(os.getpgid(host_pairs[pair_name]["client_proc"].pid), signal.SIGTERM)
        continue

    status = f"Run: {pair_name}, server: {server}, client: {client}"
    print(status)
    # Build redis-server with GCC compiler, default parameters and given commit on AWS instance (with internet access)
    command = ssh_prefix.format(server) + f"'cd redis_bench_fork/tools &&  ./run_server.sh gcc default {commit} |& tee run_server_gcc_default_{commit}.log'"
    print('\t' + command)
    host_pairs[pair_name]["server_proc"] = subprocess.Popen(command, shell=True, preexec_fn=os.setsid, stdout=host_pairs[pair_name]["server_log"], stderr=host_pairs[pair_name]["server_log"], stdin=subprocess.PIPE)
    
    # Run iperf for client
    server_ip = host_pairs[pair_name]['server_ip_address']
    command = ssh_prefix.format(client) + f"'cd redis_bench_fork/tools && ./run_client.sh gcc default {redis_bench_version} {num_runs} {server_ip} |& tee run_client_gcc_default_{commit}_{pair_name}.log' && " + scp_prefix.format(client, pair_name)
    print('\t' + command)
    host_pairs[pair_name]["client_proc"] = subprocess.Popen(command, shell=True, preexec_fn=os.setsid, stdout=host_pairs[pair_name]["client_log"], stderr=host_pairs[pair_name]["client_log"], stdin=subprocess.PIPE)

    tests.append(pair_name)

i = 0
while len(tests) > 0:
    next_tests = list()
    time.sleep(60)
    for test in tests:
        if host_pairs[test]["client_proc"].poll() is not None:
            #host_pairs[test]["server_proc"].kill()
            os.killpg(os.getpgid(host_pairs[test]["server_proc"].pid), signal.SIGTERM)
            host_pairs[test]["server_log"].flush()
            host_pairs[test]["server_log"].close()
            host_pairs[test]["client_log"].flush()
            host_pairs[test]["client_log"].close()
            print(f"{i:2}m: {test} finished")
        else:
            print(f"{i:2}m: {test} still running")
            next_tests.append(test)
    tests = next_tests
    i += 1
print("FINISHED")

