#!/usr/bin/env python3
"""
DeFi Hack Labs Transaction Analysis Script

This script:
1. Extracts transaction hashes from *_exp.sol files
2. Queries Tenderly API for transaction traces
3. Uses DeepSeek API to analyze root causes
4. Generates detailed analysis reports
"""

import os
import re
import json
import requests
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import concurrent.futures
from concurrent.futures import ThreadPoolExecutor

# Configuration
TENDERLY_BASE_URL = "https://api.tenderly.co/api/v1/public-contract"
TENDERLY_AUTH_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2NvdW50X2lkIjoiNTY3YWQ1ZTEtYzUxNi00NWI1LWI5YmYtZDQ1MWFhYzYzZGMzIiwic2Vzc2lvbl9ub25jZSI6NiwidmFsaWRfdG8iOjE3NDM4NDE2NjV9.9pR6SJomb9vk6c70wSRvBB5t3SdYext9h-hE0X2Eo2g"
DEEPSEEK_API_KEY = "sk-430607f5a0b14b25ab6a97eeb7d39ec3"
DEEPSEEK_BASE_URL = "https://api.deepseek.com/v1/chat/completions"

# Headers for API requests
TENDERLY_HEADERS = {
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7',
    'authorization': f'Bearer {TENDERLY_AUTH_TOKEN}',
    'origin': 'https://dashboard.tenderly.co',
    'priority': 'u=1, i',
    'referer': 'https://dashboard.tenderly.co/',
    'sec-ch-ua': '"Google Chrome";v="137", "Chromium";v="137", "Not/A)Brand";v="24"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"macOS"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-site',
    'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36'
}

DEEPSEEK_HEADERS = {
    'Content-Type': 'application/json',
    'Authorization': f'Bearer {DEEPSEEK_API_KEY}'
}

class TransactionExtractor:
    """Extract transaction information from exploit files"""
    
    def __init__(self, source_dir: str = "source"):
        self.source_dir = Path(source_dir)
        self.tx_hash_patterns = [
            r'https://(?:etherscan\.io|bscscan\.com|polygonscan\.com|arbiscan\.io|ftmscan\.com|snowtrace\.io|blastscan\.io|lineascan\.build|basescan\.org|optimistic\.etherscan\.io)/tx/0x([a-fA-F0-9]{64})',
            r'https://(?:explorer\.phalcon\.xyz|app\.blocksec\.com)/(?:tx/)?(?:eth/|bsc/|polygon/|arbitrum/|optimism/|base/|blast/)?(?:tx/)?0x([a-fA-F0-9]{64})',
            r'0x([a-fA-F0-9]{64})',  # Direct hash pattern
        ]
    
    def extract_tx_info_from_file(self, file_path: Path) -> Dict:
        """Extract transaction information from a single exploit file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Extract basic information
            info = {
                'file_path': str(file_path),
                'project_name': file_path.parent.name,
                'date': file_path.parent.parent.name,
                'tx_hashes': [],
                'attacker_addresses': [],
                'vulnerable_contracts': [],
                'attack_contracts': [],
                'total_lost': None,
                'network': self._detect_network(content),
                'poc_code': content
            }
            
            # Extract transaction hashes
            tx_hashes = set()
            for pattern in self.tx_hash_patterns:
                matches = re.findall(pattern, content, re.IGNORECASE)
                for match in matches:
                    if isinstance(match, tuple):
                        tx_hashes.add(match[-1])  # Take the hash part
                    else:
                        tx_hashes.add(match)
            
            # Filter valid transaction hashes (64 hex chars)
            valid_hashes = []
            for tx_hash in tx_hashes:
                if len(tx_hash) == 64 and all(c in '0123456789abcdefABCDEF' for c in tx_hash):
                    valid_hashes.append(f"0x{tx_hash}" if not tx_hash.startswith('0x') else tx_hash)
            
            info['tx_hashes'] = list(set(valid_hashes))
            
            # Extract addresses and amounts
            info['attacker_addresses'] = self._extract_addresses(content, r'[Aa]ttacker.*?0x([a-fA-F0-9]{40})')
            info['vulnerable_contracts'] = self._extract_addresses(content, r'[Vv]ulnerable.*?[Cc]ontract.*?0x([a-fA-F0-9]{40})')
            info['attack_contracts'] = self._extract_addresses(content, r'[Aa]ttack.*?[Cc]ontract.*?0x([a-fA-F0-9]{40})')
            info['total_lost'] = self._extract_total_lost(content)
            
            return info
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            return None
    
    def _detect_network(self, content: str) -> str:
        """Detect blockchain network from content"""
        network_indicators = {
            'ethereum': ['etherscan.io', 'mainnet', 'eth_', 'createSelectFork("mainnet"'],
            'bsc': ['bscscan.com', 'bsc', 'bnb', 'createSelectFork("bsc"'],
            'polygon': ['polygonscan.com', 'polygon', 'matic', 'createSelectFork("polygon"'],
            'arbitrum': ['arbiscan.io', 'arbitrum', 'createSelectFork("arbitrum"'],
            'optimism': ['optimistic.etherscan.io', 'optimism', 'createSelectFork("optimism"'],
            'base': ['basescan.org', 'base', 'createSelectFork("base"'],
            'blast': ['blastscan.io', 'blast', 'createSelectFork("blast"'],
        }
        
        content_lower = content.lower()
        for network, indicators in network_indicators.items():
            if any(indicator in content_lower for indicator in indicators):
                return network
        return 'unknown'
    
    def _extract_addresses(self, content: str, pattern: str) -> List[str]:
        """Extract addresses using regex pattern"""
        matches = re.findall(pattern, content, re.IGNORECASE)
        return [f"0x{addr}" for addr in matches]
    
    def _extract_total_lost(self, content: str) -> Optional[str]:
        """Extract total lost amount from content"""
        patterns = [
            r'[Tt]otal [Ll]ost.*?[\$:]?\s*([\d,]+(?:\.\d+)?)\s*([A-Z]{3,4}|\$)',
            r'[Ll]ost.*?[\$:]?\s*([\d,]+(?:\.\d+)?)\s*([A-Z]{3,4}|\$)',
        ]
        
        for pattern in patterns:
            matches = re.findall(pattern, content)
            if matches:
                return f"{matches[0][0]} {matches[0][1]}"
        return None
    
    def extract_all_tx_info(self) -> List[Dict]:
        """Extract transaction information from all exploit files"""
        all_info = []
        
        # Find all *_exp.sol files in source directory
        exp_files = list(self.source_dir.glob("**/*_exp.sol"))
        
        print(f"Found {len(exp_files)} exploit files")
        
        with ThreadPoolExecutor(max_workers=10) as executor:
            future_to_file = {executor.submit(self.extract_tx_info_from_file, file): file for file in exp_files}
            
            for future in concurrent.futures.as_completed(future_to_file):
                result = future.result()
                if result:
                    all_info.append(result)
        
        return all_info

class TenderlyAPI:
    """Interface for Tenderly API"""
    
    def __init__(self):
        self.base_url = TENDERLY_BASE_URL
        self.headers = TENDERLY_HEADERS
        self.session = requests.Session()
        self.session.headers.update(self.headers)
        
        # Network ID mapping
        self.network_ids = {
            'ethereum': '1',
            'bsc': '56',
            'polygon': '137',
            'arbitrum': '42161',
            'optimism': '10',
            'base': '8453',
            'blast': '81457',
            'avalanche': '43114',
            'fantom': '250',
            'unknown': '1'  # Default to Ethereum
        }
    
    def get_transaction_trace(self, tx_hash: str, network: str = 'ethereum') -> Optional[Dict]:
        """Get transaction trace from Tenderly"""
        try:
            # Ensure hash has 0x prefix for Tenderly API
            if not tx_hash.startswith('0x'):
                tx_hash = f"0x{tx_hash}"
            
            # Get network ID
            network_id = self.network_ids.get(network.lower(), '1')
            
            # Build URL with network ID and trace endpoint
            url = f"{self.base_url}/{network_id}/trace/{tx_hash}"
            
            print(f"🔗 Querying Tenderly URL: {url}")
            print(f"   📍 Network: {network} (ID: {network_id})")
            response = self.session.get(url, timeout=30)
            
            # Accept both 200 (OK) and 202 (Accepted) as successful responses
            if response.status_code in [200, 202]:
                data = response.json()
                
                # Check if we have the expected trace data (new format)
                trace_info = []
                if 'call_trace' in data and data['call_trace']:
                    call_trace = data['call_trace']
                    trace_info.append("call_trace: detailed execution trace")
                    
                    # Check nested calls
                    if 'calls' in call_trace and call_trace['calls']:
                        trace_info.append(f"nested_calls: {len(call_trace['calls'])} items")
                
                # Check logs
                if 'logs' in data and data['logs']:
                    trace_info.append(f"logs: {len(data['logs'])} events")
                
                # Check asset changes (very important for DeFi analysis)
                if 'asset_changes' in data and data['asset_changes']:
                    trace_info.append(f"asset_changes: {len(data['asset_changes'])} transfers")
                
                # Check balance changes
                if 'balance_changes' in data and data['balance_changes']:
                    trace_info.append(f"balance_changes: {len(data['balance_changes'])} items")
                
                if 'transaction_id' in data:
                    trace_info.append(f"transaction_id: {data['transaction_id']}")
                if 'contract_address' in data:
                    trace_info.append(f"contract: {data['contract_address']}")
                
                if trace_info:
                    print(f"✅ Successfully retrieved trace data for {tx_hash} (status: {response.status_code})")
                    print(f"   📊 Trace data: {', '.join(trace_info)}")
                else:
                    print(f"⚠️ No trace data found in response for {tx_hash}")
                
                return data
            else:
                print(f"❌ Tenderly API error for {tx_hash}: {response.status_code}")
                print(f"Response: {response.text[:200]}...")
                return None
                
        except Exception as e:
            print(f"❌ Error querying Tenderly for {tx_hash}: {e}")
            return None

class DeepSeekAnalyzer:
    """Analyzer using DeepSeek API"""
    
    def __init__(self):
        self.api_key = DEEPSEEK_API_KEY
        self.base_url = DEEPSEEK_BASE_URL
        self.headers = DEEPSEEK_HEADERS
    
    def analyze_root_cause(self, tx_info: Dict, trace_data: Dict) -> Optional[str]:
        """Analyze root cause using DeepSeek API"""
        try:
            # Prepare the analysis prompt
            prompt = self._create_analysis_prompt(tx_info, trace_data)
            
            payload = {
                "model": "deepseek-chat",
                "messages": [
                    {
                        "role": "system",
                        "content": "You are an expert blockchain security analyst specializing in DeFi exploit analysis. Provide detailed, technical root cause analysis."
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                "temperature": 0.1,
                "max_tokens": 4000
            }
            
            response = requests.post(self.base_url, headers=self.headers, json=payload, timeout=120)
            
            if response.status_code == 200:
                result = response.json()
                return result['choices'][0]['message']['content']
            else:
                print(f"DeepSeek API error: {response.status_code}")
                return None
                
        except Exception as e:
            print(f"Error with DeepSeek analysis: {e}")
            return None
    
    def _create_analysis_prompt(self, tx_info: Dict, trace_data: Dict) -> str:
        """Create detailed analysis prompt"""
        prompt = f"""
# DeFi Exploit Analysis Request

## Project Information
- **Project Name**: {tx_info.get('project_name', 'Unknown')}
- **Date**: {tx_info.get('date', 'Unknown')}
- **Network**: {tx_info.get('network', 'Unknown')}
- **Total Lost**: {tx_info.get('total_lost', 'Unknown')}

## Transaction Hashes
{', '.join(tx_info.get('tx_hashes', []))}

## Addresses Involved
- **Attacker**: {', '.join(tx_info.get('attacker_addresses', []))}
- **Vulnerable Contract**: {', '.join(tx_info.get('vulnerable_contracts', []))}
- **Attack Contract**: {', '.join(tx_info.get('attack_contracts', []))}

## POC Code
```solidity
{tx_info.get('poc_code', '')[:3000]}...
```

## Transaction Trace Data
{self._format_trace_for_analysis(trace_data)}

## Analysis Request
Please provide a comprehensive root cause analysis including:

1. **Vulnerability Summary**: Brief description of the main vulnerability
2. **Technical Details**: Step-by-step breakdown of the exploit
3. **Root Cause**: What specific code/logic flaw enabled the attack
4. **Attack Vector**: How the attacker exploited the vulnerability
5. **Impact Assessment**: Financial and technical impact
6. **Mitigation Strategies**: How this could have been prevented
7. **Lessons Learned**: Key takeaways for developers

Please focus on technical accuracy and provide actionable insights.
        """
        return prompt
    
    def _format_trace_for_analysis(self, trace_data: Dict) -> str:
        """Format trace data for AI analysis"""
        if not trace_data:
            return "No trace data available"
        
        formatted = []
        
        # Basic transaction info
        formatted.append("### Transaction Overview")
        formatted.append(f"- **Transaction ID**: {trace_data.get('transaction_id', 'N/A')}")
        formatted.append(f"- **Block Number**: {trace_data.get('block_number', 'N/A')}")
        formatted.append(f"- **Contract Address**: {trace_data.get('contract_address', 'N/A')}")
        formatted.append(f"- **Gas Used**: {trace_data.get('call_trace', {}).get('gas_used', 'N/A')}")
        
        # Asset Changes (most important for DeFi exploits)
        if trace_data.get('asset_changes'):
            formatted.append("\n### Asset Changes (Token Transfers)")
            for i, change in enumerate(trace_data['asset_changes'][:20]):  # Show first 20
                if change.get('type') == 'Transfer':
                    token_info = change.get('token_info', {})
                    formatted.append(f"**Transfer #{i+1}:**")
                    formatted.append(f"  - Token: {token_info.get('symbol', 'Unknown')} ({token_info.get('name', 'Unknown')})")
                    formatted.append(f"  - Amount: {change.get('amount', '0')}")
                    formatted.append(f"  - Raw Amount: {change.get('raw_amount', '0')}")
                    formatted.append(f"  - USD Value: ${change.get('dollar_value', '0')}")
                    formatted.append(f"  - From: {change.get('from', 'N/A')}")
                    formatted.append(f"  - To: {change.get('to', 'N/A')}")
                    formatted.append("")
        
        # Balance Changes
        if trace_data.get('balance_changes'):
            formatted.append("### Balance Changes")
            for i, balance_change in enumerate(trace_data['balance_changes'][:10]):  # Show first 10
                formatted.append(f"**Balance Change #{i+1}:**")
                formatted.append(f"  - Address: {balance_change.get('address', 'N/A')}")
                formatted.append(f"  - Before: {balance_change.get('before', 'N/A')}")
                formatted.append(f"  - After: {balance_change.get('after', 'N/A')}")
                formatted.append("")
        
        # Function Calls Summary
        if trace_data.get('call_trace', {}).get('calls'):
            calls = trace_data['call_trace']['calls']
            formatted.append(f"### Function Calls ({len(calls)} total)")
            for i, call in enumerate(calls[:10]):  # Show first 10
                formatted.append(f"**Call #{i+1}:**")
                formatted.append(f"  - Type: {call.get('call_type', 'N/A')}")
                formatted.append(f"  - From: {call.get('from', 'N/A')}")
                formatted.append(f"  - To: {call.get('to', 'N/A')}")
                formatted.append(f"  - Gas Used: {call.get('gas_used', 'N/A')}")
                formatted.append(f"  - Function: {call.get('function_op', 'N/A')}")
                formatted.append("")
        
        # Event Logs Summary
        if trace_data.get('logs'):
            formatted.append(f"### Event Logs ({len(trace_data['logs'])} total)")
            formatted.append("Note: Detailed event logs available in full trace data")
            formatted.append("")
        
        # State Changes
        if trace_data.get('state_diff'):
            formatted.append(f"### State Changes ({len(trace_data['state_diff'])} modifications)")
            formatted.append("Note: Contract storage state was modified during execution")
            formatted.append("")
        
        return '\n'.join(formatted)

class ReportGenerator:
    """Generate comprehensive analysis reports"""
    
    def generate_report(self, tx_info: Dict, trace_data: Dict, analysis: str) -> str:
        """Generate formatted analysis report"""
        report = f"""# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: {tx_info.get('project_name', 'Unknown')}
- **Date**: {tx_info.get('date', 'Unknown')}
- **Network**: {tx_info.get('network', 'Unknown').title()}
- **Total Loss**: {tx_info.get('total_lost', 'Unknown')}

## 🎯 Attack Overview
- **Transaction Hash(es)**: {', '.join(tx_info.get('tx_hashes', []))}
- **Attacker Address(es)**: {', '.join(tx_info.get('attacker_addresses', []))}
- **Vulnerable Contract(s)**: {', '.join(tx_info.get('vulnerable_contracts', []))}
- **Attack Contract(s)**: {', '.join(tx_info.get('attack_contracts', []))}

## 🔍 Technical Analysis

{analysis}

## 📈 Transaction Trace Summary
{self._format_trace_summary(trace_data)}

## 🔗 References
- **POC File**: {tx_info.get('file_path', 'Unknown')}
- **Blockchain Explorer**: [View Transaction]({self._get_explorer_url(tx_info)})

---
*Generated by DeFi Hack Labs Analysis Tool*
"""
        return report
    
    def _format_trace_summary(self, trace_data: Dict) -> str:
        """Format trace data summary"""
        if not trace_data:
            return "No trace data available"
        
        summary = []
        
        # Basic transaction info
        if 'transaction_id' in trace_data:
            summary.append(f"- **Transaction ID**: {trace_data['transaction_id']}")
        
        if 'block_number' in trace_data:
            summary.append(f"- **Block Number**: {trace_data['block_number']:,}")
        
        if 'contract_address' in trace_data:
            summary.append(f"- **Contract Address**: {trace_data['contract_address']}")
        
        # Gas information
        if 'intrinsic_gas' in trace_data:
            summary.append(f"- **Intrinsic Gas**: {trace_data['intrinsic_gas']:,}")
        if 'refund_gas' in trace_data:
            summary.append(f"- **Refund Gas**: {trace_data['refund_gas']:,}")
        
        # Call trace information
        if 'call_trace' in trace_data and trace_data['call_trace']:
            call_trace = trace_data['call_trace']
            if 'gas_used' in call_trace:
                summary.append(f"- **Gas Used**: {call_trace['gas_used']:,}")
            if 'call_type' in call_trace:
                summary.append(f"- **Call Type**: {call_trace['call_type']}")
            if 'calls' in call_trace and call_trace['calls']:
                summary.append(f"- **Nested Function Calls**: {len(call_trace['calls'])}")
        
        # Event logs
        if 'logs' in trace_data and trace_data['logs']:
            summary.append(f"- **Event Logs**: {len(trace_data['logs'])}")
        
        # Asset changes (critical for DeFi analysis)
        if 'asset_changes' in trace_data and trace_data['asset_changes']:
            summary.append(f"- **Asset Changes**: {len(trace_data['asset_changes'])} token transfers")
            
            # Show top token transfers
            transfers = []
            for change in trace_data['asset_changes'][:5]:  # Show first 5
                if change.get('type') == 'Transfer':
                    token_symbol = change.get('token_info', {}).get('symbol', 'Unknown')
                    amount = change.get('amount', '0')
                    dollar_value = change.get('dollar_value', '0')
                    transfers.append(f"{amount} {token_symbol} (${dollar_value})")
            
            if transfers:
                summary.append(f"- **Top Transfers**: {', '.join(transfers[:3])}")
        
        # Balance changes
        if 'balance_changes' in trace_data and trace_data['balance_changes']:
            summary.append(f"- **Balance Changes**: {len(trace_data['balance_changes'])} accounts affected")
        
        # State changes
        if 'state_diff' in trace_data and trace_data['state_diff']:
            summary.append(f"- **State Changes**: {len(trace_data['state_diff'])} storage modifications")
        
        # Method info
        if 'method' in trace_data and trace_data['method']:
            summary.append(f"- **Method**: {trace_data['method']}")
        
        return '\n'.join(summary) if summary else "Trace data format not recognized"
    
    def _get_explorer_url(self, tx_info: Dict) -> str:
        """Get blockchain explorer URL"""
        if not tx_info.get('tx_hashes'):
            return "#"
        
        tx_hash = tx_info['tx_hashes'][0]
        network = tx_info.get('network', 'ethereum')
        
        explorers = {
            'ethereum': 'https://etherscan.io/tx/',
            'bsc': 'https://bscscan.com/tx/',
            'polygon': 'https://polygonscan.com/tx/',
            'arbitrum': 'https://arbiscan.io/tx/',
            'optimism': 'https://optimistic.etherscan.io/tx/',
            'base': 'https://basescan.org/tx/',
            'blast': 'https://blastscan.io/tx/',
        }
        
        base_url = explorers.get(network, 'https://etherscan.io/tx/')
        return f"{base_url}{tx_hash}"

def main():
    """Main execution function"""
    print("🚀 Starting DeFi Hack Labs Transaction Analysis")
    
    # Initialize components
    extractor = TransactionExtractor()
    tenderly = TenderlyAPI()
    analyzer = DeepSeekAnalyzer()
    reporter = ReportGenerator()
    
    # Extract transaction information
    print("📝 Extracting transaction information...")
    all_tx_info = extractor.extract_all_tx_info()
    print(f"✅ Extracted info from {len(all_tx_info)} projects")
    
    # Process each project
    total_projects = len(all_tx_info)
    processed = 0
    
    for tx_info in all_tx_info:
        processed += 1
        project_name = tx_info.get('project_name', 'Unknown')
        print(f"\n🔍 Processing {project_name} ({processed}/{total_projects})")
        
        # Skip if no transaction hashes
        if not tx_info.get('tx_hashes'):
            print(f"⚠️ No transaction hashes found for {project_name}")
            continue
        
        # Get trace data from Tenderly
        trace_data = None
        network = tx_info.get('network', 'ethereum')
        for tx_hash in tx_info['tx_hashes'][:3]:  # Limit to first 3 hashes
            print(f"🔗 Querying Tenderly for {tx_hash}")
            trace = tenderly.get_transaction_trace(tx_hash, network)
            if trace:
                trace_data = trace
                break
            time.sleep(1)  # Rate limiting
        
        # Analyze with DeepSeek
        print(f"🧠 Analyzing root cause with DeepSeek...")
        analysis = analyzer.analyze_root_cause(tx_info, trace_data)
        
        if not analysis:
            print(f"❌ Failed to analyze {project_name}")
            continue
        
        # Generate report
        report = reporter.generate_report(tx_info, trace_data, analysis)
        
        # Save report
        report_dir = Path(tx_info['file_path']).parent
        report_file = report_dir / "ROOT_CAUSE_ANALYSIS.md"
        
        try:
            with open(report_file, 'w', encoding='utf-8') as f:
                f.write(report)
            print(f"✅ Saved analysis report to {report_file}")
        except Exception as e:
            print(f"❌ Failed to save report for {project_name}: {e}")
        
        # Rate limiting
        time.sleep(2)
    
    print(f"\n🎉 Analysis complete! Processed {processed} projects")

if __name__ == "__main__":
    main() 