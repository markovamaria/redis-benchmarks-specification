import pandas as pd
import argparse
from scipy import stats
import os
import re

def get_priorities(directory):
    priority_map = {"Test Name": [], "Priority":[]}
    line_view = r'priority:\s+(\d+)'

    for filename in os.listdir(directory):
        with open(os.path.join(directory, filename), "r") as file:
            for line in file.readlines():
                match = re.search(line_view, line)
                if match:
                    number= match.group(1)
                    priority_map["Test Name"].append(filename.split(".yml")[0])
                    priority_map["Priority"].append(int(number))

    return priority_map


#def add_priority(df):
#    pfile2=pd.read_csv("priorities", sep=r'[:.]', names=["Test Name", "yml", "p", "Priority"])
#    pfile=pfile2[["Test Name", "Priority"]]
#
#    res_df =  df.reset_index().merge(pfile, left_on='Test Name', right_on='Test Name', how="left")[["Test Name", "Priority", "Run1", "Run2", "Run3",  "Diff *", "Average", "Min"]]
#    return res_df


def add_priority_v2(df, N):
    directory_path = '../redis_benchmarks_specification/test-suites/' # relative path to test suites configs
    priority_map = get_priorities(directory_path)

    pfile = pd.DataFrame.from_dict(priority_map)
    res_df =  df.reset_index().merge(pfile, left_on='Test Name', right_on='Test Name', how="left")[["Test Name", "Priority", *df.columns[:N],  "Diff *", "Average", "Min"]]
    return res_df

def main():
    parser = argparse.ArgumentParser(description='Get results from redis-benchmark runs.')
    parser.add_argument('--exp', '-e', type=str, help='Experiment name, e.g. gcc_default', required=True)
    parser.add_argument('--runs', '-r', type=int, help='Number of runs, e.g. 5', required=True)

    args = parser.parse_args()
    exp_type = args.exp
    N = args.runs  # num runs
    dflist:list = []

    for r in range(1,N+1):
        file = 'runs_' + exp_type + '/run_' + str(r) + '/aggregate-results.csv'  
        df = pd.read_csv(file)
        df = df[df['Metric JSON Path'].str.contains("Ops/sec")].drop(columns=["Metric JSON Path"]).rename(columns={"Metric Value": "Run" + str(r) })
        dflist.append(df)

    dflist = [df.set_index('Test Name') for df in dflist]
    df = pd.concat(dflist, axis=1)
    df_min = df.min(axis=1)
    df_diff = df.max(axis=1) / df.min(axis=1) - 1
    df_av = df.mean(axis=1)
    df['Diff *'] = df_diff
    df['Average'] = df_av
    df['Min'] = df_min

    # add row
    df.loc['Geomean'] = stats.gmean(df)
    df.at['Geomean', 'Diff *'] = float(df.iloc[[-1],0:N].max(axis=1) / df.iloc[[-1],0:N].min(axis=1) - 1)


    res_df = add_priority_v2(df, N)
    res_df[:-1] = res_df[:-1].sort_values(by=["Priority", "Test Name"])
    print(res_df)


    # Save results file
    results_filename = f'results_{exp_type}.csv'
    res_df.to_csv(results_filename, index=False)

    # Copy results file to runs_<exp_type> folder
    runs_folder = f'runs_{exp_type}'
    if os.path.isdir(runs_folder):
        import shutil
        dest_path = os.path.join(runs_folder, results_filename)
        shutil.copyfile(results_filename, dest_path)
        print(f"Copied {results_filename} to {dest_path}")
    else:
        print(f"Warning: {runs_folder} does not exist. Results file not copied.")

    # with open('server_pid') as f:
        # server_pid=f.readline().strip('\n')
    # kill(server_pid, SIGKILL)


if __name__ == "__main__":
    main()

