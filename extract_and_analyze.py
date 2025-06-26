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
import requests.exceptions
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import concurrent.futures
from concurrent.futures import ThreadPoolExecutor

# Configuration
TENDERLY_BASE_URL = "https://api.tenderly.co/api/v1/public-contract"
TENDERLY_AUTH_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2NvdW50X2lkIjoiNTY3YWQ1ZTEtYzUxNi00NWI1LWI5YmYtZDQ1MWFhYzYzZGMzIiwic2Vzc2lvbl9ub25jZSI6NiwidmFsaWRfdG8iOjE3NDM4NDE2NjV9.9pR6SJomb9vk6c70wSRvBB5t3SdYext9h-hE0X2Eo2g"

# DeepSeek Configuration
DEEPSEEK_API_KEY = "sk-34b54effa6154e99b20833809ea77945"
DEEPSEEK_BASE_URL = "https://api.deepseek.com/v1/chat/completions"

# Model Configuration
USE_REASONING_MODEL = True  # Set to True to use DeepSeek R1, False for regular deepseek-chat
REASONING_MODEL_NAME = "deepseek-reasoner"  # DeepSeek-R1-0528 reasoning model
REGULAR_MODEL_NAME = "deepseek-chat"  # DeepSeek-V3-0324 regular model

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
            r'(?:Attack Tx|Transaction|Tx).*?0x([a-fA-F0-9]{64})',  # Transaction hash in comments
            r'//.*?(?:tx|transaction).*?0x([a-fA-F0-9]{64})',  # Transaction hash in comments
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
    """Advanced DeepSeek Analyzer supporting both regular and reasoning models"""
    
    def __init__(self, use_reasoning: bool = USE_REASONING_MODEL):
        self.api_key = DEEPSEEK_API_KEY
        self.base_url = DEEPSEEK_BASE_URL
        self.headers = DEEPSEEK_HEADERS
        self.use_reasoning = use_reasoning
        
        if use_reasoning:
            self.model_name = REASONING_MODEL_NAME
            self.is_reasoning_model = True
            print(f"🧠 Using DeepSeek Reasoning Model: {self.model_name} (DeepSeek-R1-0528)")
            print("⚡ Reasoning mode enabled - expect deeper analysis but longer processing time")
        else:
            self.model_name = REGULAR_MODEL_NAME
            self.is_reasoning_model = False
            print(f"🧠 Using Regular DeepSeek Model: {self.model_name} (DeepSeek-V3-0324)")
            
        print(f"🔗 API Base URL: {self.base_url}")
    
    def analyze_root_cause(self, tx_info: Dict, trace_data: Dict) -> Optional[str]:
        """Analyze root cause using DeepSeek API with optional reasoning model"""
        try:
            # Get contract source codes
            contract_sources = self._get_contract_sources(tx_info)
            
            # Prepare the analysis prompt
            prompt = self._create_analysis_prompt(tx_info, trace_data, contract_sources)
            
            # Configure payload based on model type
            if self.is_reasoning_model:
                # DeepSeek R1 reasoning model configuration
                payload = {
                    "model": self.model_name,
                    "messages": [
                        {
                            "role": "user",
                            "content": f"""You are an elite blockchain security researcher with deep expertise in DeFi exploit analysis. Use your reasoning capabilities to conduct a comprehensive technical analysis.

{prompt}

Please use step-by-step reasoning to:
1. Carefully analyze the contract source code to identify the exact vulnerability
2. Trace through the execution flow using the provided trace data
3. Explain how the POC exploits the identified weakness
4. Derive a comprehensive vulnerability pattern that can be used to find similar issues
5. Provide actionable detection and mitigation strategies

Think through each step carefully and provide detailed technical reasoning for your conclusions."""
                        }
                    ]
                    # Note: R1 models don't support temperature, max_tokens, or system messages
                }
                timeout = 300  # Longer timeout for reasoning models
            else:
                # Regular DeepSeek model configuration
                payload = {
                    "model": self.model_name,
                    "messages": [
                        {
                            "role": "system",
                            "content": """You are an elite blockchain security researcher and exploit analyst with deep expertise in:
- Smart contract vulnerabilities and attack vectors
- On-chain transaction analysis and trace interpretation
- Solidity/EVM internals and assembly-level analysis
- DeFi protocol security and economic attack mechanisms
- Vulnerability pattern recognition and classification

Your analysis style is:
- Extremely technical and detailed
- Evidence-based (every claim backed by trace data or code)
- Focused on actionable insights for security researchers
- Oriented toward creating reusable knowledge patterns

You excel at:
- Correlating transaction traces with source code
- Identifying subtle vulnerability patterns
- Explaining complex attack mechanisms step-by-step
- Creating detection methodologies for vulnerability classes
- Providing concrete, implementable security recommendations

Your goal is to produce analysis that serves as a reference for finding and preventing similar vulnerabilities across the DeFi ecosystem."""
                        },
                        {
                            "role": "user",
                            "content": prompt
                        }
                    ],
                    "temperature": 0.1,
                    "max_tokens": 8000
                }
                timeout = 120
            
            print(f"🚀 Sending request to DeepSeek {self.model_name}...")
            if self.is_reasoning_model:
                print("⏳ Reasoning model is thinking deeply - this may take a while...")
                
            response = requests.post(self.base_url, headers=self.headers, json=payload, timeout=timeout)
            
            if response.status_code == 200:
                result = response.json()
                analysis_content = result['choices'][0]['message']['content']
                
                # Log token usage if available
                if 'usage' in result:
                    usage = result['usage']
                    print(f"📊 Token usage - Prompt: {usage.get('prompt_tokens', 'N/A')}, Completion: {usage.get('completion_tokens', 'N/A')}, Total: {usage.get('total_tokens', 'N/A')}")
                
                if self.is_reasoning_model:
                    print("✅ Reasoning analysis completed with deep technical insights")
                else:
                    print("✅ Standard analysis completed")
                    
                return analysis_content
            else:
                print(f"❌ DeepSeek API error: {response.status_code}")
                print(f"Response: {response.text[:300]}...")
                return None
                
        except requests.exceptions.Timeout:
            print(f"⏰ Request timeout after {timeout}s - reasoning models can take longer")
            return None
        except Exception as e:
            print(f"❌ Error with DeepSeek analysis: {e}")
            return None
    
    def _get_contract_sources(self, tx_info: Dict) -> Dict[str, str]:
        """Get contract source codes from the _exp directory"""
        contract_sources = {}
        
        try:
            # Get the directory path from file_path
            file_path = Path(tx_info.get('file_path', ''))
            exp_dir = file_path.parent
            
            # Find all .sol files in the directory (except the POC file itself)
            sol_files = list(exp_dir.glob("*.sol"))
            
            for sol_file in sol_files:
                # Skip the POC file itself since we already have it
                if sol_file.name == file_path.name:
                    continue
                
                try:
                    with open(sol_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                        # Limit file size to avoid token limit issues
                        if len(content) > 50000:  # ~50KB limit per file
                            content = content[:50000] + "\n\n// ... (truncated for analysis) ..."
                        contract_sources[sol_file.name] = content
                        print(f"📄 Loaded contract source: {sol_file.name} ({len(content)} chars)")
                except Exception as e:
                    print(f"⚠️ Could not read {sol_file.name}: {e}")
                    
        except Exception as e:
            print(f"⚠️ Error loading contract sources: {e}")
        
        return contract_sources
    
    def _create_analysis_prompt(self, tx_info: Dict, trace_data: Dict, contract_sources: Dict[str, str] = None) -> str:
        """Create detailed analysis prompt"""
        
        # Format contract sources section
        contract_sources_section = ""
        if contract_sources:
            contract_sources_section = "## Contract Source Codes\n\n"
            for filename, source_code in contract_sources.items():
                contract_sources_section += f"### {filename}\n```solidity\n{source_code}\n```\n\n"
        
        prompt = f"""
# DeFi Exploit Deep Analysis Request

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

## POC Source Code
```solidity
{tx_info.get('poc_code', '')[:6000]}...
```

{contract_sources_section}

## Transaction Trace Data
{self._format_trace_for_analysis(trace_data)}

## Deep Analysis Requirements

Please provide an extremely detailed technical analysis that combines the CONTRACT SOURCE CODE, POC CODE, and TRANSACTION TRACE DATA. This is a comprehensive analysis that must deeply examine the actual vulnerable contract implementation.

### 1. **Vulnerability Summary**
- Brief description of the main vulnerability type
- Classification (e.g., reentrancy, price manipulation, logic flaw, etc.)
- Identify the exact vulnerable function(s) in the contract source code

### 2. **Step-by-Step Exploit Analysis (EXTREMELY DETAILED)**
**Critical Requirements:**
- For each step, you MUST reference the actual contract source code (not just POC)
- Correlate each step with specific function calls from the trace data
- Reference specific lines/functions in BOTH the vulnerable contract AND the POC code
- Explain exactly what happens at the EVM/Solidity level
- Show how each function call modifies contract state
- Trace the exact flow of funds through the contracts
- Include gas consumption and why certain operations succeed/fail

**Mandatory Format for Each Step:**
```
Step X: [Detailed Description]
- Trace Evidence: [Exact function call signature, input data, output from trace]
- Contract Code Reference: [Specific function name, line numbers, and code snippet from vulnerable contract]
- POC Code Reference: [How the POC triggers this step]
- EVM State Changes: [Exact storage/memory changes]
- Fund Flow: [How tokens/ETH move between addresses]
- Technical Mechanism: [Why this step works at the blockchain level]
- Vulnerability Exploitation: [How this step exploits the bug]
```

**Additional Requirements:**
- Analyze AT LEAST 10-15 detailed steps
- For each asset transfer in the trace, explain the contract logic that enabled it
- Cross-reference function calls in trace with actual contract functions
- Explain how the POC manipulates the vulnerable contract's state

### 3. **Root Cause Deep Dive (Contract Source Code Analysis)**
**Requirements:**
- Quote the EXACT vulnerable code from the contract source code (function names, line numbers)
- Explain the specific implementation flaw in the contract code
- Show line-by-line how the vulnerability manifests in the source code
- Compare vulnerable code patterns with secure implementations
- Include assembly/Yul code analysis where relevant
- Demonstrate how the contract's state management is flawed

**Format:**
```
Vulnerable Code Location: [Contract file name, function name, approximate line numbers]
Code Snippet:
[Exact vulnerable code from source]

Flaw Analysis:
- [What's wrong with this code]
- [Why the implementation is insecure]
- [What the developer missed or did incorrectly]

Exploitation Mechanism:
- [How the POC manipulates this code]
- [What inputs/conditions trigger the vulnerability]
```

### 4. **Technical Exploit Mechanics**
- Detailed explanation of why each attack step succeeds
- How the attacker bypassed security mechanisms
- Mathematical/cryptographic principles involved (if any)
- Memory/storage manipulation techniques used

### 5. **Bug Pattern Identification**
**Provide a reusable bug pattern template:**
```
Bug Pattern: [Name]
Description: [What this vulnerability pattern looks like]
Code Characteristics:
- [Specific code patterns to look for]
- [Common implementation mistakes]
- [Dangerous function combinations]

Detection Methods:
- [Static analysis techniques]
- [Code review checklist items]
- [Automated tools that can catch this]

Variants:
- [Different ways this bug can manifest]
- [Related vulnerability patterns]
```

### 6. **Vulnerability Detection Guide**
**How to find similar vulnerabilities:**
- Specific code patterns to search for in other projects
- Static analysis rules that would catch this bug type
- Manual code review techniques
- Testing strategies to uncover similar flaws
- Tools and queries for large-scale detection

### 7. **Impact Assessment**
- Precise financial impact calculation
- Technical impact on protocol functionality
- Potential for similar attacks on other protocols

### 8. **Advanced Mitigation Strategies**
- Immediate fixes with code examples
- Long-term architectural improvements
- Defense-in-depth strategies
- Monitoring and detection systems

### 9. **Lessons for Security Researchers**
- How this vulnerability type can be discovered
- Research methodologies that would uncover similar issues
- Red flags during code review
- Testing approaches for this bug class

## Critical Requirements:
1. **MANDATORY Source Code Analysis**: You MUST extensively reference and quote from the actual contract source code. Every technical claim must be backed by specific code snippets from the vulnerable contracts.

2. **Trace-Code Correlation**: For every function call in the trace data, identify and explain the corresponding function in the contract source code. Show how the trace execution flow maps to the contract logic.

3. **Detailed Step-by-Step Analysis**: Provide at least 10-15 extremely detailed steps that combine:
   - Exact trace data (function calls, inputs, outputs)
   - Specific contract source code being executed
   - POC code that triggers each step
   - State changes and fund movements

4. **Assembly/Yul Analysis**: Since this appears to involve Yul optimization, analyze the relevant assembly code in the contracts and explain how it's exploited.

5. **Vulnerability Pattern Recognition**: Create a comprehensive bug pattern template that can be used to find similar vulnerabilities in other contracts.

6. **Actionable Detection Methods**: Provide specific, implementable techniques for finding similar bugs, including:
   - Exact code patterns to search for
   - Static analysis rules
   - Manual review techniques

**IMPORTANT**: This analysis must be a comprehensive technical deep-dive that serves as a definitive reference for understanding this vulnerability class. Do not provide superficial analysis - every claim must be backed by specific code references and trace evidence.
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
        formatted.append(f"- **Gas Limit**: {trace_data.get('gas_limit', 'N/A')}")
        formatted.append(f"- **Gas Price**: {trace_data.get('gas_price', 'N/A')}")
        formatted.append(f"- **Value**: {trace_data.get('value', 'N/A')}")
        formatted.append("")
        
        # Asset Changes (most important for DeFi exploits)
        if trace_data.get('asset_changes'):
            formatted.append("### Asset Changes (Critical for Exploit Analysis)")
            for i, change in enumerate(trace_data['asset_changes'][:25]):  # Show more transfers
                if change.get('type') == 'Transfer':
                    token_info = change.get('token_info', {})
                    formatted.append(f"**Transfer #{i+1}:**")
                    formatted.append(f"  - Token: {token_info.get('symbol', 'Unknown')} ({token_info.get('name', 'Unknown')})")
                    formatted.append(f"  - Contract: {token_info.get('address', 'N/A')}")
                    formatted.append(f"  - Decimals: {token_info.get('decimals', 'N/A')}")
                    formatted.append(f"  - Amount: {change.get('amount', '0')}")
                    formatted.append(f"  - Raw Amount: {change.get('raw_amount', '0')}")
                    formatted.append(f"  - USD Value: ${change.get('dollar_value', '0')}")
                    formatted.append(f"  - From: {change.get('from', 'N/A')}")
                    formatted.append(f"  - To: {change.get('to', 'N/A')}")
                    if change.get('trace_address'):
                        formatted.append(f"  - Trace Address: {change.get('trace_address', 'N/A')}")
                    formatted.append("")
        
        # Balance Changes
        if trace_data.get('balance_changes'):
            formatted.append("### Balance Changes")
            for i, balance_change in enumerate(trace_data['balance_changes'][:15]):  # Show more
                formatted.append(f"**Balance Change #{i+1}:**")
                formatted.append(f"  - Address: {balance_change.get('address', 'N/A')}")
                formatted.append(f"  - Before: {balance_change.get('before', 'N/A')}")
                formatted.append(f"  - After: {balance_change.get('after', 'N/A')}")
                formatted.append(f"  - Difference: {balance_change.get('diff', 'N/A')}")
                formatted.append("")
        
        # Detailed Function Calls
        if trace_data.get('call_trace', {}).get('calls'):
            calls = trace_data['call_trace']['calls']
            formatted.append(f"### Function Calls ({len(calls)} total)")
            for i, call in enumerate(calls[:15]):  # Show more calls
                formatted.append(f"**Call #{i+1}:**")
                formatted.append(f"  - Type: {call.get('call_type', 'N/A')}")
                formatted.append(f"  - From: {call.get('from', 'N/A')}")
                formatted.append(f"  - To: {call.get('to', 'N/A')}")
                formatted.append(f"  - Value: {call.get('value', 'N/A')}")
                formatted.append(f"  - Gas Used: {call.get('gas_used', 'N/A')}")
                formatted.append(f"  - Gas: {call.get('gas', 'N/A')}")
                formatted.append(f"  - Function: {call.get('function_op', 'N/A')}")
                formatted.append(f"  - Function Name: {call.get('function_name', 'N/A')}")
                if call.get('input'):
                    formatted.append(f"  - Input Data: {call.get('input', 'N/A')[:100]}...")
                if call.get('output'):
                    formatted.append(f"  - Output: {call.get('output', 'N/A')[:100]}...")
                formatted.append("")
        
        # Event Logs (detailed)
        if trace_data.get('logs'):
            formatted.append(f"### Event Logs ({len(trace_data['logs'])} total)")
            for i, log in enumerate(trace_data['logs'][:20]):  # Show more logs
                formatted.append(f"**Event #{i+1}:**")
                formatted.append(f"  - Address: {log.get('address', 'N/A')}")
                formatted.append(f"  - Topics: {log.get('topics', 'N/A')}")
                formatted.append(f"  - Data: {log.get('data', 'N/A')[:100]}...")
                if log.get('decoded'):
                    formatted.append(f"  - Decoded: {log.get('decoded', 'N/A')}")
                formatted.append("")
        
        # State Changes (detailed)
        if trace_data.get('state_diff'):
            formatted.append(f"### State Changes ({len(trace_data['state_diff'])} modifications)")
            for i, state_change in enumerate(trace_data['state_diff'][:15]):  # Show more changes
                formatted.append(f"**State Change #{i+1}:**")
                formatted.append(f"  - Address: {state_change.get('address', 'N/A')}")
                formatted.append(f"  - Key: {state_change.get('key', 'N/A')}")
                formatted.append(f"  - Before: {state_change.get('before', 'N/A')}")
                formatted.append(f"  - After: {state_change.get('after', 'N/A')}")
                formatted.append("")
        
        # Main call trace details
        if trace_data.get('call_trace'):
            main_trace = trace_data['call_trace']
            formatted.append("### Main Call Trace Details")
            formatted.append(f"- **From**: {main_trace.get('from', 'N/A')}")
            formatted.append(f"- **To**: {main_trace.get('to', 'N/A')}")
            formatted.append(f"- **Value**: {main_trace.get('value', 'N/A')}")
            formatted.append(f"- **Gas**: {main_trace.get('gas', 'N/A')}")
            formatted.append(f"- **Gas Used**: {main_trace.get('gas_used', 'N/A')}")
            formatted.append(f"- **Call Type**: {main_trace.get('call_type', 'N/A')}")
            if main_trace.get('input'):
                formatted.append(f"- **Input**: {main_trace.get('input', 'N/A')[:200]}...")
            if main_trace.get('output'):
                formatted.append(f"- **Output**: {main_trace.get('output', 'N/A')[:200]}...")
            formatted.append("")
        
        # Additional metadata
        if trace_data.get('metadata'):
            formatted.append("### Additional Metadata")
            metadata = trace_data['metadata']
            for key, value in metadata.items():
                formatted.append(f"- **{key}**: {value}")
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