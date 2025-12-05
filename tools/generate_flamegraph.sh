#!/bin/bash

# Script to generate flame graph from perf data
# Usage: ./generate_flamegraph.sh <perf_data_file> [output_dir]

if [ "$1" = "" ]
then
    echo "Usage: $0 <perf_data_file> [output_dir]"
    echo "Example: $0 run_server_logs/perf_gcc_default_fafbf53.data run_server_logs"
    exit 1
fi

PERF_DATA=$1
OUTPUT_DIR=${2:-.}
PERF_SCRIPT="${OUTPUT_DIR}/perf_script.txt"
FOLDED="${OUTPUT_DIR}/perf_folded.txt"
FLAMEGRAPH="${OUTPUT_DIR}/flamegraph.svg"

# Check if perf data file exists
if [ ! -f "$PERF_DATA" ]
then
    echo "Error: Perf data file not found: $PERF_DATA"
    exit 1
fi

echo "Generating flame graph from $PERF_DATA"

# Fix permissions on perf data file if needed
if [ ! -r "$PERF_DATA" ]
then
    echo "Fixing permissions on perf data file..."
    sudo chmod 644 "$PERF_DATA"
fi

# Step 1: Generate perf script
echo "Step 1: Converting perf data to script format..."
perf script -i "$PERF_DATA" > "$PERF_SCRIPT" 2>&1
if [ ! -s "$PERF_SCRIPT" ]
then
    echo "Warning: perf script generated empty output, trying with sudo..."
    sudo perf script -i "$PERF_DATA" > "$PERF_SCRIPT"
fi

# Step 2: Check if FlameGraph tools are available
if ! command -v stackcollapse-perf.pl &> /dev/null
then
    echo "FlameGraph tools not found. Installing..."
    git clone https://github.com/brendangregg/FlameGraph.git /tmp/FlameGraph
    export PATH=$PATH:/tmp/FlameGraph
fi

# Step 3: Fold the stack traces
echo "Step 2: Folding stack traces..."
stackcollapse-perf.pl "$PERF_SCRIPT" > "$FOLDED"

if [ ! -s "$FOLDED" ]
then
    echo "Error: stackcollapse-perf.pl produced no output"
    echo "Checking perf script size:"
    ls -lh "$PERF_SCRIPT"
    exit 1
fi

# Step 4: Generate the flame graph
echo "Step 3: Generating flame graph SVG..."
flamegraph.pl --color=java "$FOLDED" > "$FLAMEGRAPH"

if [ ! -s "$FLAMEGRAPH" ]
then
    echo "Error: flamegraph.pl produced no output"
    exit 1
fi

echo "Flame graph generated: $FLAMEGRAPH"
echo "Open it in a web browser to view the interactive flame graph."
