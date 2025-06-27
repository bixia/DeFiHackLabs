#!/usr/bin/env python3
"""
Single Project Analysis Script

This script runs analysis on a specific project using the enhanced prompt.
"""

import os
import sys
from pathlib import Path

# Add the current directory to the path so we can import from extract_and_analyze
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from extract_and_analyze import TransactionExtractor, TenderlyAPI, DeepSeekAnalyzer, ReportGenerator

def analyze_single_project(project_path: str):
    """Analyze a single project"""
    
    print(f"🎯 Analyzing single project: {project_path}")
    
    # Initialize components
    extractor = TransactionExtractor()
    tenderly = TenderlyAPI()
    analyzer = DeepSeekAnalyzer(use_reasoning=True)  # Force reasoning model
    reporter = ReportGenerator()
    
    # Extract information from the specific project
    project_file = Path(project_path)
    if not project_file.exists():
        print(f"❌ File not found: {project_path}")
        return
    
    print(f"📝 Extracting transaction information from {project_file.name}...")
    tx_info = extractor.extract_tx_info_from_file(project_file)
    
    if not tx_info:
        print(f"❌ Failed to extract transaction info from {project_path}")
        return
    
    print(f"✅ Extracted info for {tx_info.get('project_name', 'Unknown')}")
    print(f"   📍 Network: {tx_info.get('network', 'Unknown')}")
    print(f"   💰 Total Lost: {tx_info.get('total_lost', 'Unknown')}")
    print(f"   🔗 Transaction Hashes: {len(tx_info.get('tx_hashes', []))}")
    
    # Skip if no transaction hashes
    if not tx_info.get('tx_hashes'):
        print(f"⚠️ No transaction hashes found for {tx_info.get('project_name', 'Unknown')}")
        return
    
    # Get trace data from Tenderly
    print(f"🔗 Querying Tenderly for transaction traces...")
    trace_data = None
    network = tx_info.get('network', 'ethereum')
    
    for tx_hash in tx_info['tx_hashes'][:1]:  # Only check first hash for single analysis
        print(f"   🔍 Checking {tx_hash}")
        trace = tenderly.get_transaction_trace(tx_hash, network)
        if trace:
            trace_data = trace
            print(f"   ✅ Successfully retrieved trace data")
            break
        else:
            print(f"   ❌ Failed to get trace for {tx_hash}")
    
    # Analyze with DeepSeek
    print(f"🧠 Analyzing root cause with DeepSeek R1 (Reasoning Model)...")
    print("⏳ This may take several minutes due to deep reasoning analysis...")
    
    analysis = analyzer.analyze_root_cause(tx_info, trace_data)
    
    if not analysis:
        print(f"❌ Failed to analyze {tx_info.get('project_name', 'Unknown')}")
        return
    
    # Generate report
    print(f"📄 Generating comprehensive analysis report...")
    report = reporter.generate_report(tx_info, trace_data, analysis)
    
    # Save report
    report_dir = project_file.parent
    report_file = report_dir / "ENHANCED_ROOT_CAUSE_ANALYSIS.md"
    
    try:
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(report)
        print(f"✅ Saved enhanced analysis report to {report_file}")
        print(f"📊 Report size: {len(report):,} characters")
    except Exception as e:
        print(f"❌ Failed to save report: {e}")
        return
    
    print(f"🎉 Analysis complete for {tx_info.get('project_name', 'Unknown')}!")
    print(f"📁 Report saved at: {report_file}")

def main():
    """Main execution function"""
    print("🚀 Starting Single Project DeFi Analysis")
    
    # Default to YBToken_exp for demonstration
    project_path = "source/2025-04/YBToken_exp/YBToken_exp.sol"
    
    # Allow command line argument
    if len(sys.argv) > 1:
        project_path = sys.argv[1]
    
    analyze_single_project(project_path)

if __name__ == "__main__":
    main() 