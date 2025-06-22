import os
import re
import subprocess
from datetime import datetime
from pathlib import Path

# Configuration
TEST_DIR = "/home/comcat/dev/DeFiHackLabs/src/test"
OUTPUT_BASE_DIR = "/home/comcat/dev/DeFiHackLabs/source"

# Chain configurations from PRD
CHAIN_CONFIGS = {
    'ethereum': {
        'api_key': 'VI1Q4M1M6XP2M5B648UIYR3JNVFE47KQW7',
        'chain': 'mainnet',
        'api_url': 'https://api.etherscan.io/api',
        'rpc_url': 'https://eth.llamarpc.com'
    },
    'bsc': {
        'api_key': 'GSWUVKIT9HZ28Y9TQEA1VZ6GH5S21MV812',
        'chain': 'bsc',
        'api_url': 'https://api.bscscan.com/api',
        'rpc_url': 'https://bsc-dataseed.binance.org'
    },
    'polygon': {
        'api_key': '661P25T9WH169UD5VWIIG3SYX7E6XVJ2VK',
        'chain': 'polygon',
        'api_url': 'https://api.polygonscan.com/api',
        'rpc_url': 'https://polygon-rpc.com'
    },
    'base': {
        'api_key': 'A2XDTUCD1GXC1KC749NKQ3GD57QTJV6JR6',
        'chain': 'base',
        'api_url': 'https://api.basescan.org/api'
    },
    'linea': {
        'api_key': 'B3GS3V4DV543W5GAG1VN1RT8626Z9JAAPU',
        'chain': 'linea',
        'api_url': 'https://api.lineascan.build/api'
    },
    'arbitrum': {
        'api_key': 'VD3HX86J6TITE1WVT9HEESQ7AIPE11MCI5',
        'chain': 'arbitrum',
        'api_url': 'https://api.arbiscan.io/api'
    },
    'scroll': {
        'api_key': '29G1U3GQVYUHAB9HG98STRU3PB6PUXMD7U',
        'chain': 'scroll',
        'api_url': 'https://api.scrollscan.com/api'
    },
    'optimism': {
        'api_key': 'CX9VVKT7G6CDM527KIXSDKQDZCUI5ZR9PU',
        'chain': 'optimism',
        'api_url': 'https://api-optimistic.etherscan.io/api'
    },
    'opbnb': {
        'api_key': '8417C2YNPY2V22R8SJY5EDMUDJ6MCXXTRF',
        'chain': 'opbnb',
        'api_url': 'https://api-opbnb.bscscan.com/api'
    },
    'taiko': {
        'api_key': 'NU11I5I1I36APW53D47RMMIT6WWCVEZY7E',
        'chain': 'taiko',
        'api_url': 'https://api.taikoscan.io/api'
    },
    'mantle': {
        'api_key': 'IVP1X8CP1UN742D8WGSUU2XW9KXJQGMSBD',
        'chain': 'mantle',
        'api_url': 'https://api.mantlescan.io/api'
    },
    'fantom': {
        'api_key': '5VEVTEHGW7D17S4JNVCJZ2ZKTR5SFDQ3IB',
        'chain': 'fantom',
        'api_url': 'https://api.ftmscan.com/api'
    },
    'blast': {
        'api_key': '4TNSUKDMZHYDKSZN63X8D2KKWPMTSGY7CN',
        'chain': 'blast',
        'api_url': 'https://api.blastscan.io/api'
    },
    'xlayer': {
        'api_key': 'ad971a56-1334-40de-b341-530d841d38e5',
        'chain': 'xlayer',
        'api_url': 'https://api.xlayerscan.io/api'
    }
}

def extract_contract_address(file_content):
    """Extract contract address from test file content."""
    # Look for common patterns of contract addresses
    patterns = [
        r'0x[a-fA-F0-9]{40}',  # Standard Ethereum address
        r'address\s*=\s*["\'](0x[a-fA-F0-9]{40})["\']',
        r'deploy\s*\(\s*["\'](0x[a-fA-F0-9]{40})["\']',
        r'contract\s*=\s*["\'](0x[a-fA-F0-9]{40})["\']',
    ]
    
    for pattern in patterns:
        matches = re.findall(pattern, file_content)
        if matches:
            # Print found address for debugging
            address = matches[0] if isinstance(matches[0], str) else matches[0][0]
            print(f"Found contract address: {address}")
            return address
    return None

def determine_chain(file_content):
    """Determine the chain from test file content."""
    # Look for chain indicators in the file
    chain_indicators = {
        'bsc': ['bsc', 'binance', 'bscscan'],
        'ethereum': ['ethereum', 'mainnet', 'etherscan'],
        'polygon': ['polygon', 'matic'],
        'base': ['base'],
        'linea': ['linea'],
        'arbitrum': ['arbitrum'],
        'scroll': ['scroll'],
        'optimism': ['optimism'],
        'opbnb': ['opbnb'],
        'taiko': ['taiko'],
        'mantle': ['mantle'],
        'fantom': ['fantom'],
        'blast': ['blast'],
        'xlayer': ['xlayer']
    }
    
    content_lower = file_content.lower()
    for chain, indicators in chain_indicators.items():
        if any(indicator in content_lower for indicator in indicators):
            return chain
    return 'ethereum'  # Default to ethereum if no chain is found

def get_contract_source(address, chain):
    """Get contract source code using cast command."""
    if chain not in CHAIN_CONFIGS:
        print(f"Unsupported chain: {chain}")
        return None
    
    config = CHAIN_CONFIGS[chain]
    try:
        # Set the appropriate API key environment variable
        env = os.environ.copy()
        env_var_name = f"{chain.upper()}SCAN_API_KEY"
        env[env_var_name] = config['api_key']
        
        # Set ETH_RPC_URL environment variable
        env['ETH_RPC_URL'] = config['rpc_url']
        
        print(f"Fetching source code for {address} on {chain}...")
        print(f"Using RPC URL: {config['rpc_url']}")
        
        cmd = ['cast', 'ct', address, '--flatten', '--chain', config['chain']]
        print(f"Running command: {' '.join(cmd)}")
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            env=env
        )
        
        if result.returncode != 0:
            print(f"Error from cast command: {result.stderr}")
            return None
            
        if not result.stdout.strip():
            print("Warning: Empty source code received")
            return None
            
        return result.stdout
    except Exception as e:
        print(f"Error getting contract source: {e}")
        return None

def process_test_file(file_path):
    """Process a single test file."""
    print(f"\nProcessing test file: {file_path}")
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        address = extract_contract_address(content)
        if not address:
            print(f"No contract address found in {file_path}")
            return
        
        chain = determine_chain(content)
        print(f"Detected chain: {chain}")
        
        source_code = get_contract_source(address, chain)
        
        if not source_code:
            print(f"Failed to get source code for {address} on {chain}")
            return
        
        # Create output directory
        date_str = datetime.now().strftime('%Y-%m-%d')
        test_file_name = os.path.basename(file_path)
        output_dir = os.path.join(OUTPUT_BASE_DIR, date_str)
        os.makedirs(output_dir, exist_ok=True)
        
        # Save source code
        output_file = os.path.join(output_dir, f"{test_file_name}.sol")
        with open(output_file, 'w') as f:
            f.write(source_code)
        
        print(f"Successfully saved source code to {output_file}")
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")

def main():
    # Get all test files ordered by modification time (newest first)
    test_files = []
    for root, _, files in os.walk(TEST_DIR):
        for file in files:
            if file.endswith('.sol'):
                file_path = os.path.join(root, file)
                test_files.append((file_path, os.path.getmtime(file_path)))
    
    # Sort by modification time (newest first)
    test_files.sort(key=lambda x: x[1], reverse=True)
    
    # Process each test file
    for file_path, _ in test_files:
        process_test_file(file_path)

if __name__ == "__main__":
    main() 