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
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configuration
TENDERLY_BASE_URL = "https://api.tenderly.co/api/v1/public-contract"
TENDERLY_AUTH_TOKEN = os.getenv('TENDERLY_AUTH_TOKEN')

# DeepSeek Configuration
DEEPSEEK_API_KEY = os.getenv('DEEPSEEK_API_KEY')
DEEPSEEK_BASE_URL = "https://api.deepseek.com/v1/chat/completions"

# Validate API keys are loaded
if not DEEPSEEK_API_KEY:
    raise ValueError("DEEPSEEK_API_KEY not found in environment variables. Please check your .env file.")
if not TENDERLY_AUTH_TOKEN:
    raise ValueError("TENDERLY_AUTH_TOKEN not found in environment variables. Please check your .env file.")

# Model Configuration
USE_REASONING_MODEL = True  # Set to True to use DeepSeek R1, False for regular deepseek-chat
# USE_REASONING_MODEL = False  # Set to True to use DeepSeek R1, False for regular deepseek-chat
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

## CRITICAL STEP 1: IDENTIFY THE VULNERABLE CONTRACT

**MANDATORY FIRST TASK**: You MUST correctly identify which contract contains the core vulnerability based on:

1. **Project Name Analysis**: The project name "{tx_info.get('project_name', 'Unknown')}" indicates the main vulnerable contract
2. **File Naming Convention**: Look for contracts whose names match or relate to the project name
3. **POC Analysis**: Examine which contract the POC is primarily targeting/exploiting
4. **Transaction Flow**: Identify which contract's functions are being manipulated

**VULNERABLE CONTRACT IDENTIFICATION CRITERIA:**
- If project name is "XYZToken_exp" → Focus on XYZ Token contract
- If project name mentions a specific protocol → Focus on that protocol's main contract  
- If project name is generic → Analyze POC to determine the main target contract

**OUTPUT REQUIRED:**
```
PRIMARY VULNERABLE CONTRACT: [Contract Name and Address]
REASONING: [Why this contract is the main vulnerability source]
BUSINESS LOGIC TO ANALYZE: [What business operations of this contract will be examined]
```

## CRITICAL STEP 2: TRACE-DRIVEN VULNERABILITY ANALYSIS

**MANDATORY: Every claim must be backed by specific trace evidence**

### 🔍 TRACE DATA INTEGRATION REQUIREMENTS:

**1. STEP-BY-STEP TRACE ANALYSIS (CRITICAL)**
You MUST analyze the attack flow using the actual transaction trace data:

**A. Asset Movement Proof:**
For each critical step, provide:
```
Step X: [Attack Step Description]
Trace Evidence:
- Asset Transfer: [Specific transfer from asset_changes: Token X, Amount Y, From Z to W]
- Function Call: [Exact function called from function_calls with parameters]
- Gas Used: [Gas consumption for this operation]
- Storage Changes: [State modifications from state_diff]
- Event Logs: [Relevant events from logs that prove this step occurred]

Business Logic Violation:
- Expected Behavior: [What should have happened according to contract design]
- Actual Behavior: [What actually happened according to trace]
- Evidence of Failure: [Specific trace data showing business logic breakdown]
```

**B. Quantitative Vulnerability Proof:**
```
Pre-Attack State:
- Token Balances: [From balance_changes data]
- LP Reserves: [From trace or asset_changes]
- Contract State: [From state_diff]

Attack Execution:
- Manipulation Steps: [Each step with trace evidence]
- State Changes: [Exact storage modifications]
- Balance Deltas: [Precise balance changes from trace]

Post-Attack State:
- Profit Calculation: [Exact amounts from asset_changes]
- Contract Damage: [State corruption evidence from trace]
- Victim Losses: [Balance reductions from balance_changes]
```

### 🎯 MANDATORY ANALYSIS REQUIREMENTS:

**1. VULNERABLE CONTRACT BUSINESS MODEL ANALYSIS (CRITICAL)**

**A. Core Business Purpose & Economics:**
- What specific business problem does this contract solve?
- What is the intended revenue generation mechanism?
- How does the fee structure serve the business model?
- What user behavior was the contract designed to incentivize?

**B. Token Economics Deep Dive (If Token Contract):**
```
From the vulnerable contract source code, analyze:
- Token Purpose: [What is this token designed for?]
- Fee Structure: [What fees are charged and why?]
- Transfer Logic: [How do transfers work differently from standard ERC20?]
- Special Functions: [What unique business operations does this token enable?]
- Reward/Penalty Mechanisms: [How does the token incentivize/discourage behavior?]
- Business Value Proposition: [What benefit do users get from this token?]
```

**C. Access Control & Business Permissions:**
```
- Owner/Admin Functions: [What special business privileges exist?]
- User Role Categories: [How are different user types treated in the business model?]
- Function Restrictions: [What business limitations exist on operations?]
- Business Rationale: [Why were these restrictions implemented from a business perspective?]
```

**2. CONTRACT DESIGN ASSUMPTIONS ANALYSIS (CRITICAL)**

**A. Developer Business Intent Analysis:**
```
For each major function in the vulnerable contract:
Function: [name]
Business Intent: [What business operation was this supposed to enable?]
Expected Usage: [How did developers expect users to interact with this?]
Design Assumptions: [What did developers assume about usage patterns?]
Economic Logic: [How does this function contribute to the business model?]
```

**B. Business Model Assumptions:**
- What user behavior did the economic model assume?
- What market conditions was the contract optimized for?
- What competitive advantages was the business model supposed to provide?
- What business risks were considered vs. overlooked?

**3. BUSINESS LOGIC VULNERABILITY IDENTIFICATION (CRITICAL)**

**A. Business Logic Flaw Analysis:**
```
For the identified vulnerable functions:
- Business Operation: [What business function does this enable?]
- Implementation Logic: [How is this business operation coded?]
- Business Logic Gap: [Where does the implementation fail to match business intent?]
- Exploitation Opportunity: [How can this gap be exploited?]
- Economic Impact: [How does this affect the contract's economic model?]
- Trace Evidence: [Specific trace data proving this business logic failure]
```

**B. Fee/Incentive System Business Analysis:**
```
- Fee Calculation Logic: [Exact implementation from source code]
- Business Rationale: [Why were fees structured this way?]
- Economic Behavior Design: [What behavior was this supposed to encourage?]
- Edge Case Handling: [How do fees behave under unusual business conditions?]
- Exploitation Vector: [How can fee logic be manipulated?]
- Trace Proof: [Evidence from trace showing fee system exploitation]
```

**4. BUSINESS LOGIC EXPLOITATION EVIDENCE (TRACE-BACKED)**

**A. Business Model Breakdown Analysis:**
```
Business Assumption 1: [What did developers assume about how this contract would be used?]
Trace Evidence: [Specific trace data showing assumption violation]
Reality: [How does the attack violate this assumption?]
Business Impact: [Why does this assumption failure break the business model?]

Business Assumption 2: [What did developers assume about user economic behavior?]
Trace Evidence: [Trace data proving different behavior]
Reality: [How does the attacker behave differently?]
Business Impact: [How does this threaten the contract's intended function?]
```

**B. Economic Model Manipulation Evidence:**
```
Intended Economic Behavior: [What economic behavior was the contract designed to encourage?]
Actual Economic Exploitation: [How does the attack create unintended economic opportunities?]
Trace Evidence: [Specific asset_changes and function_calls proving manipulation]
Business Model Breakdown: [How does this exploitation undermine the business model?]
Quantified Impact: [Exact damage to business model from trace data]
```

### 1. **Vulnerable Contract Business Analysis (Trace-Driven)**

**MANDATORY: Use trace data to understand actual vs intended business operations**

**A. Trace-Revealed Business Model Failures:**
```
From trace function_calls, identify:
- Which contract functions were called most frequently?
- What were the intended business purposes of these functions?
- How did the actual usage (from trace) differ from intended usage?
- What business assumptions were violated by the attack sequence?

Evidence Required:
- Function call frequency analysis from trace
- Parameter patterns that reveal business model misuse
- State change patterns that show business logic failures
- Asset flow patterns that violate economic design
```

**B. Business Economics vs. Actual Execution:**
```
Business Revenue Model: [How was the contract supposed to make money?]
Trace Evidence: [Function calls related to revenue generation]
Revenue Model Failure: [How did the attack break revenue generation?]
Economic Logic Breakdown: [Why did the business economics fail?]
```

### 2. **Contract Implementation Business Logic Analysis (Trace-Proven)**

**Focus on proving business logic vulnerabilities using specific trace evidence**

**A. Code-Trace-Business Correlation Analysis:**
For each vulnerable function identified:
```
Function: [name from contract source]
Business Purpose: [What business operation does this enable?]
Intended Business Behavior: [from source code analysis]
Actual Execution: [proven by trace data]

Business Logic Implementation Gap:
- Business Requirement: [What the business needed]
- Code Implementation: [How it was coded]
- Execution Reality: [What trace shows happened]
- Business Failure Point: [Where business logic broke down]

Trace Evidence of Business Logic Malfunction:
- Function Calls: [Specific calls to this function from trace]
- Business Parameters: [Business-relevant parameters used during attack]
- Business State Changes: [Storage modifications that prove business logic failure]
- Economic Flows: [Token movements that reveal business model breakdown]
- Business Impact: [Quantified damage to business model from trace data]
```

**C. Business vs. Technical Implementation Analysis:**
```
Business Requirement: [What the business logic was supposed to achieve]
Technical Implementation: [How developers coded the business logic]
Implementation Gap: [Where technical implementation failed business requirements]
Trace Evidence: [Specific trace data proving the gap]
Attack Exploitation: [How attackers exploited the business-technical gap]
```

## CRITICAL SUCCESS CRITERIA:

1. **Trace Integration**: Every major claim must be supported by specific trace data
2. **Quantitative Evidence**: Use exact numbers from asset_changes, balance_changes, etc.
3. **Function Call Mapping**: Map each trace function call to vulnerability exploitation
4. **Step-by-Step Proof**: Show attack progression using sequential trace evidence
5. **Economic Quantification**: Calculate exact profits/losses from trace data

**PROHIBITED APPROACHES:**
- Don't make claims without trace evidence
- Don't provide generic vulnerability analysis
- Don't ignore the quantitative data in traces
- Don't analyze vulnerabilities that aren't proven by trace data

**REQUIRED EVIDENCE STANDARDS:**
1. **Asset Flow Evidence**: Every token movement must be traceable in asset_changes
2. **Function Call Evidence**: Every claimed function call must exist in function_calls
3. **State Change Evidence**: Every logic failure must show in state_diff
4. **Economic Evidence**: Every profit/loss claim must be calculable from trace data
5. **Temporal Evidence**: Attack sequence must follow trace chronology

**MANDATORY OUTPUT FORMAT:**
Each section must include:
```
CLAIM: [Vulnerability/exploitation claim]
TRACE EVIDENCE: [Specific data from transaction trace]
PROOF: [How the trace data proves the claim]
QUANTIFICATION: [Exact numbers/calculations from trace]
```

Focus on creating an analysis where every vulnerability claim is irrefutably proven by the transaction trace data.
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