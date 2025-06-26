#!/usr/bin/env python3
"""
Test script to analyze a single exploit file
"""

import sys
import os
from pathlib import Path

# Add current directory to path so we can import our modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from extract_and_analyze import TransactionExtractor, TenderlyAPI, DeepSeekAnalyzer, ReportGenerator

def test_single_file():
    """Test analysis on the H2O exploit file"""
    
    # Initialize components
    extractor = TransactionExtractor()
    tenderly = TenderlyAPI()
    analyzer = DeepSeekAnalyzer()
    reporter = ReportGenerator()
    
    # Test with H2O exploit file
    h2o_file = Path("source/2025-03/OneInchFusionV1SettlementHack.sol_exp/OneInchFusionV1SettlementHack.sol_exp.sol")
    
    if not h2o_file.exists():
        print(f"❌ File not found: {h2o_file}")
        return
    
    print(f"🔍 Analyzing {h2o_file}")
    
    # Extract transaction info
    tx_info = extractor.extract_tx_info_from_file(h2o_file)
    if not tx_info:
        print("❌ Failed to extract transaction info")
        return
    
    print(f"✅ Extracted info:")
    print(f"   - Project: {tx_info.get('project_name')}")
    print(f"   - Network: {tx_info.get('network')}")
    print(f"   - TX Hashes: {tx_info.get('tx_hashes')}")
    print(f"   - Total Lost: {tx_info.get('total_lost')}")
    
    # Get trace data from Tenderly (try first transaction hash)
    trace_data = None
    if tx_info.get('tx_hashes'):
        tx_hash = tx_info['tx_hashes'][0]
        network = tx_info.get('network', 'ethereum')
        print(f"🔗 Querying Tenderly for {tx_hash}")
        trace_data = tenderly.get_transaction_trace(tx_hash, network)
        
        if trace_data:
            print("✅ Retrieved trace data from Tenderly")
        else:
            print("⚠️ No trace data retrieved from Tenderly")
    
    # Analyze with DeepSeek
    print("🧠 Analyzing with DeepSeek...")
    analysis = analyzer.analyze_root_cause(tx_info, trace_data)
    
    if analysis:
        print("✅ Root cause analysis completed")
        
        # Generate report
        report = reporter.generate_report(tx_info, trace_data, analysis)
        
        # Save report
        report_file = h2o_file.parent / "ROOT_CAUSE_ANALYSIS.md"
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(report)
        
        print(f"✅ Report saved to {report_file}")
        
        # Print summary
        print("\n" + "="*60)
        print("ANALYSIS SUMMARY")
        print("="*60)
        print(analysis[:500] + "..." if len(analysis) > 500 else analysis)
        
    else:
        print("❌ Failed to get analysis from DeepSeek")

if __name__ == "__main__":
    test_single_file() 