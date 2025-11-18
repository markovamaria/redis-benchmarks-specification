#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Merge two benchmark result CSV files and compare Average metrics.

Usage:
    python compare_results.py file1.csv file2.csv [output.csv]
"""

import csv
import sys
import os
from pathlib import Path


def extract_average_values(csv_file):
    """
    Extract Average column values from a benchmark CSV file.
    
    Returns a dict mapping test name to Average value.
    """
    results = {}
    
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            test_name = row['Test Name']
            
            # Extract the Average column value
            if 'Average' in row:
                try:
                    average_value = float(row['Average'])
                    results[test_name] = average_value
                except (ValueError, KeyError):
                    # Skip rows with invalid or missing Average values
                    continue
    
    return results


def calculate_diff(value1, value2):
    """
    Calculate the percentage change between two values.
    
    Returns the percentage difference as a numeric string.
    """
    if value1 is None or value2 is None:
        return "N/A"
    
    if value1 == 0:
        if value2 == 0:
            return "0.00"
        else:
            return "inf"
    
    percent_change = ((value2 - value1) / value1) * 100
    
    return f"{percent_change:.2f}"


def merge_results(file1, file2, output_file=None):
    """
    Merge two benchmark CSV files and create comparison table.
    """
    # Extract filenames for column headers
    file1_name = Path(file1).stem
    file2_name = Path(file2).stem
    
    # Extract Average data from both files
    print(f"Reading {file1}...")
    results1 = extract_average_values(file1)
    print(f"  Found {len(results1)} tests with Average values")
    
    print(f"Reading {file2}...")
    results2 = extract_average_values(file2)
    print(f"  Found {len(results2)} tests with Average values")
    
    # Get all unique test names from both files
    all_tests = sorted(set(results1.keys()) | set(results2.keys()))
    print(f"\nTotal unique tests: {len(all_tests)}")
    
    # Prepare output data
    output_data = []
    
    for test_name in all_tests:
        value1 = results1.get(test_name)
        value2 = results2.get(test_name)
        
        # Format values without commas to match original format
        value1_str = f"{value1:.2f}" if value1 is not None else "N/A"
        value2_str = f"{value2:.2f}" if value2 is not None else "N/A"
        
        # Calculate difference
        diff_str = calculate_diff(value1, value2)
        
        # Remove prefix from test name for display
        display_test_name = test_name.replace('oss-standalone-memtier_benchmark-', '')
        
        output_data.append({
            'Test Name': test_name,
            'Display Name': display_test_name,
            f'Average ({file1_name})': value1_str,
            f'Average ({file2_name})': value2_str,
            'Diff %': diff_str
        })
    
    # Read full content of both files
    print(f"\nReading full content from {file1}...")
    with open(file1, 'r') as f:
        reader1 = csv.DictReader(f)
        fieldnames1 = reader1.fieldnames
        rows1 = list(reader1)
    
    print(f"Reading full content from {file2}...")
    with open(file2, 'r') as f:
        reader2 = csv.DictReader(f)
        fieldnames2 = reader2.fieldnames
        rows2 = list(reader2)
    
    # Write output
    if output_file:
        output_path = output_file
    else:
        # Generate smart filename: compare_<diff1>_<diff2>_<common_part>.csv
        # Split by both '_' and '.'
        import re
        name1_parts = re.split(r'[_.]', file1_name)
        name2_parts = re.split(r'[_.]', file2_name)
        
        # Find differences - extract only the first different part (m8g/m8i)
        first_diff1 = None
        first_diff2 = None
        common_parts = []
        
        for i, (p1, p2) in enumerate(zip(name1_parts, name2_parts)):
            if p1 != p2 and first_diff1 is None:
                first_diff1 = p1
                first_diff2 = p2
            elif p1 == p2:
                common_parts.append(p1)
        
        # Build filename: compare_<first_diff1>_<first_diff2>_<common>.csv
        diff1_str = first_diff1 if first_diff1 else 'file1'
        diff2_str = first_diff2 if first_diff2 else 'file2'
        common_str = '_'.join(common_parts) if common_parts else 'results'
        
        output_path = f"compare_{diff1_str}_{diff2_str}_{common_str}.csv"
        common_str = '_'.join(common_parts) if common_parts else 'results'
        
        output_path = f"compare_{diff1_str}_{diff2_str}_{common_str}.csv"
    
    print(f"\nWriting merged results to {output_path}...")
    
    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        
        # Build combined fieldnames: comparison table + space + file1 columns + space + file2 columns
        # Extract common and different parts from file names
        name1_parts = file1_name.split('_')
        name2_parts = file2_name.split('_')
        
        # Find differences (including the size part like m8g and 4xlarge separately)
        diff1_parts = []
        diff2_parts = []
        common_parts = []
        
        for i, (p1, p2) in enumerate(zip(name1_parts, name2_parts)):
            if p1 != p2:
                diff1_parts.append(p1)
                diff2_parts.append(p2)
            else:
                common_parts.append(p1)
        
        # Build unique names: m8g.4xlarge and m8i.4xlarge format
        # Extract the first different part (m8g/m8i) and combine with .4xlarge
        if diff1_parts and common_parts:
            # Find if '4xlarge' or similar is in common parts
            size_part = next((p for p in common_parts if 'xlarge' in p.lower()), None)
            if size_part:
                diff1_name = f"{diff1_parts[0]}.{size_part}"
                diff2_name = f"{diff2_parts[0]}.{size_part}"
                # Remove size_part from common_parts for the Average label
                common_parts_filtered = [p for p in common_parts if p != size_part]
                common_name = '_'.join(common_parts_filtered) if common_parts_filtered else ''
            else:
                diff1_name = '_'.join(diff1_parts) if diff1_parts else file1_name
                diff2_name = '_'.join(diff2_parts) if diff2_parts else file2_name
                common_name = '_'.join(common_parts) if common_parts else ''
        else:
            diff1_name = '_'.join(diff1_parts) if diff1_parts else file1_name
            diff2_name = '_'.join(diff2_parts) if diff2_parts else file2_name
            common_name = '_'.join(common_parts) if common_parts else ''
        
        comparison_fields = [
            'Test Name (oss-standalone-memtier_benchmark-*)',
            diff1_name,
            diff2_name,
            'Diff %'
        ]
        
        # Calculate column counts for each section
        num_comparison_cols = len(comparison_fields)
        num_file1_cols = len(fieldnames1)
        num_file2_cols = len(fieldnames2)
        
        # Write first header row with section labels
        # For columns 2 and 3 in comparison section, show "Average (common_name)" spanning both columns
        header_row_1 = ['Calculation', f'Average ({common_name})', '', ''] + [''] + [file1_name] + [''] * (num_file1_cols - 1) + [''] + [file2_name] + [''] * (num_file2_cols - 1)
        writer.writerow(header_row_1)
        
        # Write second header row with column names
        header_row_2 = comparison_fields + [''] + list(fieldnames1) + [''] + list(fieldnames2)
        writer.writerow(header_row_2)
        
        # Create a mapping of test names to rows for both files
        rows1_dict = {row['Test Name']: row for row in rows1}
        rows2_dict = {row['Test Name']: row for row in rows2}
        
        # Write merged data
        for comparison_row in output_data:
            test_name = comparison_row['Test Name']
            
            # Build row as a list
            row_data = [
                comparison_row['Display Name'],
                comparison_row[f'Average ({file1_name})'],
                comparison_row[f'Average ({file2_name})'],
                comparison_row['Diff %']
            ]
            
            # Add empty column space
            row_data.append('')
            
            # Add file1 data (format numbers to 2 decimal places)
            if test_name in rows1_dict:
                for field in fieldnames1:
                    value = rows1_dict[test_name].get(field, '')
                    # Remove prefix from test name, format numbers
                    if field == 'Test Name':
                        value = value.replace('oss-standalone-memtier_benchmark-', '')
                        row_data.append(value)
                    else:
                        # Try to format as float with 2 decimal places
                        try:
                            formatted_value = f"{float(value):.2f}"
                            row_data.append(formatted_value)
                        except (ValueError, TypeError):
                            # If not a number, keep as is
                            row_data.append(value)
            else:
                row_data.extend([''] * num_file1_cols)
            
            # Add second empty column space
            row_data.append('')
            
            # Add file2 data (format numbers to 2 decimal places)
            if test_name in rows2_dict:
                for field in fieldnames2:
                    value = rows2_dict[test_name].get(field, '')
                    # Remove prefix from test name, format numbers
                    if field == 'Test Name':
                        value = value.replace('oss-standalone-memtier_benchmark-', '')
                        row_data.append(value)
                    else:
                        # Try to format as float with 2 decimal places
                        try:
                            formatted_value = f"{float(value):.2f}"
                            row_data.append(formatted_value)
                        except (ValueError, TypeError):
                            # If not a number, keep as is
                            row_data.append(value)
            else:
                row_data.extend([''] * num_file2_cols)
            
            writer.writerow(row_data)
    
    print(f"✓ Successfully created {output_path}")
    
    # Print summary statistics
    print("\n" + "="*80)
    print("SUMMARY")
    print("="*80)
    
    # Calculate statistics for tests present in both files
    both_tests = [t for t in all_tests if t in results1 and t in results2]
    if both_tests:
        improvements = sum(1 for t in both_tests if results2[t] > results1[t])
        regressions = sum(1 for t in both_tests if results2[t] < results1[t])
        no_change = sum(1 for t in both_tests if results2[t] == results1[t])
        
        print(f"Tests in both files: {len(both_tests)}")
        print(f"  Improvements ({file2_name} faster): {improvements}")
        print(f"  Regressions ({file2_name} slower): {regressions}")
        print(f"  No change: {no_change}")
    
    only_in_file1 = len([t for t in all_tests if t in results1 and t not in results2])
    only_in_file2 = len([t for t in all_tests if t not in results1 and t in results2])
    
    if only_in_file1 > 0:
        print(f"\nTests only in {file1_name}: {only_in_file1}")
    if only_in_file2 > 0:
        print(f"Tests only in {file2_name}: {only_in_file2}")
    
    print("="*80)


def main():
    if len(sys.argv) < 3:
        print("Usage: python compare_results.py <file1.csv> <file2.csv> [output.csv]")
        print("\nExample:")
        print("  python compare_results.py m8g_4xlarge_results.csv m8i_4xlarge_results.csv")
        print("  python compare_results.py results1.csv results2.csv merged_comparison.csv")
        sys.exit(1)
    
    file1 = sys.argv[1]
    file2 = sys.argv[2]
    output_file = sys.argv[3] if len(sys.argv) > 3 else None
    
    # Validate input files exist
    if not os.path.exists(file1):
        print(f"Error: File '{file1}' not found")
        sys.exit(1)
    
    if not os.path.exists(file2):
        print(f"Error: File '{file2}' not found")
        sys.exit(1)
    
    merge_results(file1, file2, output_file)


if __name__ == "__main__":
    main()
