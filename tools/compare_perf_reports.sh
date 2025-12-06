#!/bin/bash

# Script to compare two perf reports
# Usage: ./compare_perf_reports.sh <perf_file1> <perf_file2> [output_dir]

if [ "$1" = "" ] || [ "$2" = "" ]
then
    echo "Usage: $0 <perf_file1> <perf_file2> [output_dir]"
    echo "Example: $0 run_server_logs/perf_gnr.data run_server_logs/perf_graviton.data analysis"
    exit 1
fi

PERF_FILE1=$1
PERF_FILE2=$2
OUTPUT_DIR=${3:-.}
NAME1=$(basename "$PERF_FILE1" .data)
NAME2=$(basename "$PERF_FILE2" .data)

# Check if files exist
if [ ! -f "$PERF_FILE1" ]
then
    echo "Error: File not found: $PERF_FILE1"
    exit 1
fi

if [ ! -f "$PERF_FILE2" ]
then
    echo "Error: File not found: $PERF_FILE2"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "Perf Report Analysis"
echo "========================================"
echo "File 1: $PERF_FILE1"
echo "File 2: $PERF_FILE2"
echo "Output: $OUTPUT_DIR"
echo "========================================"

# Determine if we need sudo (try without first)
PERF_CMD="perf"
if ! perf report -i "$PERF_FILE1" --stdio &>/dev/null 2>&1; then
    PERF_CMD="sudo perf"
fi

echo "Using command: $PERF_CMD"

# 1. Generate basic perf reports
echo ""
echo "Step 1: Generating perf reports..."
$PERF_CMD report -i "$PERF_FILE1" --stdio > "$OUTPUT_DIR/${NAME1}_report.txt" 2>&1
$PERF_CMD report -i "$PERF_FILE2" --stdio > "$OUTPUT_DIR/${NAME2}_report.txt" 2>&1

# 2. Extract top functions
echo "Step 2: Extracting top 30 functions..."
echo "=== TOP 30 FUNCTIONS: $NAME1 ===" > "$OUTPUT_DIR/top_functions_comparison.txt"
$PERF_CMD report -i "$PERF_FILE1" --stdio 2>/dev/null | grep -E "^\s+[0-9]+\.[0-9]+%\s+" | head -30 >> "$OUTPUT_DIR/top_functions_comparison.txt"

echo "" >> "$OUTPUT_DIR/top_functions_comparison.txt"
echo "=== TOP 30 FUNCTIONS: $NAME2 ===" >> "$OUTPUT_DIR/top_functions_comparison.txt"
$PERF_CMD report -i "$PERF_FILE2" --stdio 2>/dev/null | grep -E "^\s+[0-9]+\.[0-9]+%\s+" | head -30 >> "$OUTPUT_DIR/top_functions_comparison.txt"

# 3. Extract detailed stats
echo "Step 3: Extracting detailed statistics..."
echo "=== DETAILED STATS: $NAME1 ===" > "$OUTPUT_DIR/detailed_stats_comparison.txt"
$PERF_CMD report -i "$PERF_FILE1" --stdio 2>/dev/null | head -100 >> "$OUTPUT_DIR/detailed_stats_comparison.txt"

echo "" >> "$OUTPUT_DIR/detailed_stats_comparison.txt"
echo "=== DETAILED STATS: $NAME2 ===" >> "$OUTPUT_DIR/detailed_stats_comparison.txt"
$PERF_CMD report -i "$PERF_FILE2" --stdio 2>/dev/null | head -100 >> "$OUTPUT_DIR/detailed_stats_comparison.txt"

# 4. Get annotation with source if available
echo "Step 4: Extracting annotation (if available)..."
$PERF_CMD annotate -i "$PERF_FILE1" > "$OUTPUT_DIR/${NAME1}_annotate.txt" 2>&1 || echo "Annotation not available for $NAME1"
$PERF_CMD annotate -i "$PERF_FILE2" > "$OUTPUT_DIR/${NAME2}_annotate.txt" 2>&1 || echo "Annotation not available for $NAME2"

# 5. Compare function names
echo "Step 5: Comparing function distributions..."
echo "=== FUNCTION COMPARISON ===" > "$OUTPUT_DIR/function_diff.txt"

$PERF_CMD report -i "$PERF_FILE1" --stdio 2>/dev/null | grep -oE '\[[a-z_0-9\.]+\]|[a-z_][a-z_0-9]*' | sort | uniq -c | sort -rn | head -30 > "$OUTPUT_DIR/${NAME1}_functions.txt"
$PERF_CMD report -i "$PERF_FILE2" --stdio 2>/dev/null | grep -oE '\[[a-z_0-9\.]+\]|[a-z_][a-z_0-9]*' | sort | uniq -c | sort -rn | head -30 > "$OUTPUT_DIR/${NAME2}_functions.txt"

echo "Top functions in $NAME1:" >> "$OUTPUT_DIR/function_diff.txt"
cat "$OUTPUT_DIR/${NAME1}_functions.txt" >> "$OUTPUT_DIR/function_diff.txt"

echo "" >> "$OUTPUT_DIR/function_diff.txt"
echo "Top functions in $NAME2:" >> "$OUTPUT_DIR/function_diff.txt"
cat "$OUTPUT_DIR/${NAME2}_functions.txt" >> "$OUTPUT_DIR/function_diff.txt"

# 6. Generate summary
echo "Step 6: Generating summary..."
cat > "$OUTPUT_DIR/ANALYSIS_SUMMARY.txt" << 'EOF'
PERF REPORT COMPARISON SUMMARY
==============================

Files Generated:
1. top_functions_comparison.txt - Top 30 functions from both perf reports
2. detailed_stats_comparison.txt - Detailed statistics from both reports
3. function_diff.txt - Function distribution comparison
4. <name>_report.txt - Full perf reports
5. <name>_annotate.txt - Annotated assembly (if available)
6. <name>_functions.txt - Function lists

How to Read Results:
====================

1. IDENTIFY BOTTLENECK:
   - Check top_functions_comparison.txt
   - Look at the % column (CPU usage percentage)
   - Function with highest % = biggest bottleneck
   - Compare if bottleneck is same on both or different

2. ARCHITECTURE DIFFERENCES:
   - If top functions are SAME on both: Redis code issue (not arch-specific)
   - If top functions are DIFFERENT: Architecture-specific issue

3. PERFORMANCE IMPLICATIONS:
   - Higher % = More CPU time spent there
   - If one arch has higher % on same function: That arch is worse for that workload
   - If one arch has different functions: Different optimization/issue patterns

4. DRILL DOWN:
   - Open annotate files to see actual assembly
   - Look for cache misses, branch misses in detailed stats
   - Check for syscall overhead differences

Example Analysis:
=================
If GNR shows:
  45% je_ecache_alloc_grow
  20% kernel.kallsyms
  15% main

And Graviton shows:
  30% je_ecache_alloc_grow
  25% kernel.kallsyms
  20% main

Then: GNR spends more time in jemalloc (bottleneck), Graviton has more kernel overhead

Next Steps:
===========
1. Review top_functions_comparison.txt
2. Note the differences in top 5 functions
3. Calculate performance delta (GNR% - Graviton%)
4. Functions with biggest delta are the issue
EOF

echo ""
echo "========================================"
echo "Analysis Complete!"
echo "========================================"
echo "Results saved to: $OUTPUT_DIR"
echo ""
echo "Key files to review:"
echo "  1. $OUTPUT_DIR/top_functions_comparison.txt"
echo "  2. $OUTPUT_DIR/function_diff.txt"
echo "  3. $OUTPUT_DIR/ANALYSIS_SUMMARY.txt"
echo ""
echo "Next step: cat $OUTPUT_DIR/top_functions_comparison.txt"
echo "========================================"
