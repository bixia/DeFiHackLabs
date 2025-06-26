#!/usr/bin/env python3
"""
Batch analysis script for recent DeFi exploits
"""

import sys
import os
from pathlib import Path
import time

# Add current directory to path so we can import our modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from extract_and_analyze import TransactionExtractor, TenderlyAPI, DeepSeekAnalyzer, ReportGenerator

def batch_analyze_recent():
    """Analyze recent exploit files (2024-2025)"""
    
    # Initialize components
    extractor = TransactionExtractor()
    tenderly = TenderlyAPI()
    analyzer = DeepSeekAnalyzer()
    reporter = ReportGenerator()
    
    # Get recent exploit files (2024 and 2025)
    source_dir = Path("source")
    recent_dirs = []
    
    for year_dir in source_dir.glob("202*"):
        if year_dir.name >= "2024":
            for exp_dir in year_dir.glob("*_exp"):
                if exp_dir.is_dir():
                    recent_dirs.append(exp_dir)
    
    # Sort by date in descending order
    recent_dirs.sort(key=lambda p: p.as_posix(), reverse=True)
    
    # Limit to first 5 for demonstration
    # recent_dirs = recent_dirs[:5]
    
    print(f"🚀 Found {len(recent_dirs)} recent exploit directories")
    
    for i, exp_dir in enumerate(recent_dirs, 1):
        exp_file = exp_dir / f"{exp_dir.name}.sol"
        
        if not exp_file.exists():
            print(f"⚠️ File not found: {exp_file}")
            continue
            
        print(f"\n🔍 [{i}/{len(recent_dirs)}] Analyzing {exp_dir.name}")
        
        # Extract transaction info
        tx_info = extractor.extract_tx_info_from_file(exp_file)
        if not tx_info:
            print(f"❌ Failed to extract info from {exp_file}")
            continue
        
        print(f"   📊 Project: {tx_info.get('project_name')}")
        print(f"   🌐 Network: {tx_info.get('network')}")
        print(f"   💰 Loss: {tx_info.get('total_lost', 'Unknown')}")
        print(f"   🔗 Transactions: {len(tx_info.get('tx_hashes', []))}")
        
        # Skip if no transaction hashes
        if not tx_info.get('tx_hashes'):
            print(f"   ⚠️ No transaction hashes found")
            continue
        
        # Get trace data from Tenderly (try first hash)
        trace_data = None
        tx_hash = tx_info['tx_hashes'][0]
        network = tx_info.get('network', 'ethereum')
        print(f"   🔗 Querying Tenderly for {tx_hash[:20]} on {network}...")
        
        try:
            trace_data = tenderly.get_transaction_trace(tx_hash, network)
            if trace_data:
                print(f"   ✅ Retrieved trace data")
            else:
                print(f"   ⚠️ No trace data available")
        except Exception as e:
            print(f"   ❌ Tenderly error: {e}")
        
        # Analyze with DeepSeek only if trace data is available
        if trace_data:
            print(f"   🧠 Analyzing with DeepSeek...")
            try:
                analysis = analyzer.analyze_root_cause(tx_info, trace_data)
                
                if analysis:
                    print(f"   ✅ Analysis completed")
                    
                    # Generate and save report
                    report = reporter.generate_report(tx_info, trace_data, analysis)
                    report_file = exp_dir / "ROOT_CAUSE_ANALYSIS.md"
                    
                    with open(report_file, 'w', encoding='utf-8') as f:
                        f.write(report)
                    
                    print(f"   📝 Report saved to {report_file}")
                    
                    # Print brief summary
                    lines = analysis.split('\n')
                    summary_lines = [line for line in lines[:10] if line.strip()]
                    print(f"   📄 Summary: {' '.join(summary_lines)[:100]}...")
                    
                else:
                    print(f"   ❌ Analysis failed")
                    
            except Exception as e:
                print(f"   ❌ DeepSeek error: {e}")
        else:
            print("   ⏩ Skipping analysis due to missing trace data.")
        
        # Rate limiting
        time.sleep(3)
    
    print(f"\n🎉 Batch analysis complete!")

def list_available_exploits():
    """List available exploit files"""
    source_dir = Path("source")
    all_exp_files = list(source_dir.glob("**/*_exp.sol"))
    
    print(f"📊 Found {len(all_exp_files)} total exploit files:")
    
    # Group by year
    by_year = {}
    for file in all_exp_files:
        year = file.parent.parent.name
        if year not in by_year:
            by_year[year] = []
        by_year[year].append(file.parent.name)
    
    for year in sorted(by_year.keys(), reverse=True):
        print(f"   {year}: {len(by_year[year])} exploits")
        if year >= "2024":  # Show recent ones
            for exp in sorted(by_year[year])[:5]:  # First 5
                print(f"      - {exp}")
            if len(by_year[year]) > 5:
                print(f"      ... and {len(by_year[year]) - 5} more")

if __name__ == "__main__":
    print("🔍 DeFi Hack Labs Batch Analysis Tool\n")
    
    if len(sys.argv) > 1 and sys.argv[1] == "list":
        list_available_exploits()
    else:
        batch_analyze_recent() 