import os
import re
import subprocess
import json
from datetime import datetime
from pathlib import Path

# API Keys
ETHERSCAN_API_KEY = 'VI1Q4M1M6XP2M5B648UIYR3JNVFE47KQW7'
BSCSCAN_API_KEY = 'GSWUVKIT9HZ28Y9TQEA1VZ6GH5S21MV812'
POLYGONSCAN_API_KEY = '661P25T9WH169UD5VWIIG3SYX7E6XVJ2VK'
BASESCAN_API_KEY = 'A2XDTUCD1GXC1KC749NKQ3GD57QTJV6JR6'
LINEASCAN_API_KEY = 'B3GS3V4DV543W5GAG1VN1RT8626Z9JAAPU'
ARBITRUMSCAN_API_KEY = 'VD3HX86J6TITE1WVT9HEESQ7AIPE11MCI5'
SCROLLSCAN_API_KEY = '29G1U3GQVYUHAB9HG98STRU3PB6PUXMD7U'
OPSCAN_API_KEY = 'CX9VVKT7G6CDM527KIXSDKQDZCUI5ZR9PU'
OPBNBSCAN_API_KEY = '8417C2YNPY2V22R8SJY5EDMUDJ6MCXXTRF'
OPBNBSCAN_API_KEY_NODEREAL = '6c9cda175e5a428d92682c4eac5069af'
TAIKOSCAN_API_KEY = 'NU11I5I1I36APW53D47RMMIT6WWCVEZY7E'
MANTLESCAN_API_KEY = 'IVP1X8CP1UN742D8WGSUU2XW9KXJQGMSBD'
MANTASCAN_API_KEY = 'IVP1X8CP1UN742D8WGSUU2XW9KXJQGMSBD'
FTM_SCAN_API_KEY = '5VEVTEHGW7D17S4JNVCJZ2ZKTR5SFDQ3IB'
BLASTSCAN_API_KEY = '4TNSUKDMZHYDKSZN63X8D2KKWPMTSGY7CN'
XLAYERSCAN_API_KEY = 'ad971a56-1334-40de-b341-530d841d38e5'

# Chain configurations
CHAIN_CONFIGS = {
    'ethereum': {
        'api_key': ETHERSCAN_API_KEY,
        'chain': 'mainnet',
        'api_url': 'https://api.etherscan.io/api'
    },
    'bsc': {
        'api_key': BSCSCAN_API_KEY,
        'chain': 'bsc',
        'api_url': 'https://api.bscscan.com/api'
    },
    'polygon': {
        'api_key': POLYGONSCAN_API_KEY,
        'chain': 'polygon',
        'api_url': 'https://api.polygonscan.com/api'
    },
    'base': {
        'api_key': BASESCAN_API_KEY,
        'chain': 'base',
        'api_url': 'https://api.basescan.org/api'
    },
    'linea': {
        'api_key': LINEASCAN_API_KEY,
        'chain': 'linea',
        'api_url': 'https://api.lineascan.build/api'
    },
    'arbitrum': {
        'api_key': ARBITRUMSCAN_API_KEY,
        'chain': 'arbitrum',
        'api_url': 'https://api.arbiscan.io/api'
    },
    'scroll': {
        'api_key': SCROLLSCAN_API_KEY,
        'chain': 'scroll',
        'api_url': 'https://api.scrollscan.com/api'
    },
    'optimism': {
        'api_key': OPSCAN_API_KEY,
        'chain': 'optimism',
        'api_url': 'https://api-optimistic.etherscan.io/api'
    },
    'opbnb': {
        'api_key': OPBNBSCAN_API_KEY,
        'chain': 'opbnb',
        'api_url': 'https://api-opbnb.bscscan.com/api'
    },
    'taiko': {
        'api_key': TAIKOSCAN_API_KEY,
        'chain': 'taiko',
        'api_url': 'https://api.taikoscan.io/api'
    },
    'mantle': {
        'api_key': MANTLESCAN_API_KEY,
        'chain': 'mantle',
        'api_url': 'https://api.mantlescan.io/api'
    },
    'fantom': {
        'api_key': FTM_SCAN_API_KEY,
        'chain': 'fantom',
        'api_url': 'https://api.ftmscan.com/api'
    },
    'blast': {
        'api_key': BLASTSCAN_API_KEY,
        'chain': 'blast',
        'api_url': 'https://api.blastscan.io/api'
    },
    'xlayer': {
        'api_key': XLAYERSCAN_API_KEY,
        'chain': 'xlayer',
        'api_url': 'https://api.xlayerscan.io/api'
    }
}

def extract_contract_addresses(file_path):
    """Extract contract addresses and their names from a test file."""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Pattern to match address declarations like: address constant NAME_addr = 0x...;
    pattern = r'address\s+constant\s+(\w+)\s*=\s*(0x[a-fA-F0-9]{40});'
    matches = re.findall(pattern, content)
    
    return [{"name": name, "ca": address} for name, address in matches]

def get_chain_from_file(file_path):
    """Extract chain name from test file."""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Pattern to match vm.createSelectFork("chain", ...)
    pattern = r'vm\.createSelectFork\("([^"]+)"'
    match = re.search(pattern, content)
    
    if match:
        chain = match.group(1)
        # Special case for mainnet
        if chain == 'mainnet':
            return 'ethereum'
        return chain
    return None

def get_contract_source(chain, name, address, output_dir):
    """Get contract source code using cast."""
    chain_config = CHAIN_CONFIGS.get(chain)
    if not chain_config:
        print(f"Unsupported chain: {chain}")
        return False
    
    cmd = [
        'cast', 'et', address,
        '--etherscan-api-key', chain_config['api_key'],
        '-c', chain_config['chain'],
        '--flatten'
    ]
    
    print(f"Executing command: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            # Create output directory if it doesn't exist
            os.makedirs(output_dir, exist_ok=True)
            
            # Save source code to file
            output_file = os.path.join(output_dir, f"{name}_{address}.sol")
            with open(output_file, 'w') as f:
                f.write(result.stdout)
            print(f"Source code saved to: {output_file}")
            return True
        else:
            print(f"Error getting source code: {result.stderr}")
            return False
    except Exception as e:
        print(f"Error executing cast command: {e}")
        return False

def main():
    # Get the most recent test directory
    test_dir = Path("src/test")
    date_dirs = [d for d in test_dir.iterdir() if d.is_dir() and re.match(r'\d{4}-\d{2}', d.name)]
    if not date_dirs:
        print("No test directories found")
        return
    
    # Sort by date (descending)
    latest_dir = max(date_dirs, key=lambda d: datetime.strptime(d.name, "%Y-%m"))
    print(f"Processing directory: {latest_dir}")
    
    # Get all .sol files in the directory
    test_files = list(latest_dir.glob("*.sol"))
    if not test_files:
        print("No test files found")
        return
    
    # Process the first test file
    test_file = test_files[0]
    print(f"\nProcessing test file: {test_file}")
    
    # Extract contract addresses
    contracts = extract_contract_addresses(test_file)
    print("\nExtracted contracts:")
    for contract in contracts:
        print(f"Name: {contract['name']}, Address: {contract['ca']}")
    
    # Get chain
    chain = get_chain_from_file(test_file)
    if not chain:
        print("Could not determine chain from test file")
        return
    print(f"\nChain: {chain}")
    
    # Create output directory
    output_dir = Path("source") / latest_dir.name / test_file.stem
    print(f"\nOutput directory: {output_dir}")
    
    # Get source code for each contract
    for contract in contracts:
        print(f"\nGetting source code for {contract['name']} ({contract['ca']})")
        get_contract_source(chain, contract['name'], contract['ca'], output_dir)

if __name__ == "__main__":
    main() 