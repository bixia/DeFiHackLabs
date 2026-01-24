import os
import re
import subprocess
import shutil
from pathlib import Path
from datetime import datetime

# API Keys and configurations from PRD
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

def extract_contract_info(file_path):
    """Extract contract addresses, names and chain from a test file."""
    with open(file_path, 'r') as f:
        content = f.read()
        
    # Look for address declarations with names
    # Pattern matches:
    # 1. address constant NAME = 0x...
    # 2. NAME = 0x...
    # 3. TYPE NAME = TYPE(0x...)
    address_matches = re.finditer(
        r'(?:'
        r'address(?:\s+constant)?\s+(\w+)\s*=\s*(0x[a-fA-F0-9]{40})|'  # Pattern 1
        r'(\w+)\s*=\s*(?:address\()?(0x[a-fA-F0-9]{40})|'             # Pattern 2
        r'(?:\w+)\s+(\w+)\s*=\s*(?:\w+)\((0x[a-fA-F0-9]{40})\)'      # Pattern 3
        r')',
        content
    )
    
    contracts = []
    for match in address_matches:
        if match.group(1) and match.group(2):  # First pattern match
            name, address = match.group(1), match.group(2)
        elif match.group(3) and match.group(4):  # Second pattern match
            name, address = match.group(3), match.group(4)
        elif match.group(5) and match.group(6):  # Third pattern match (contract instantiation)
            name, address = match.group(5), match.group(6)
        else:
            continue
        contracts.append({"name": name, "ca": address})
    
    # Look for chain information in fork declaration
    chain_match = re.search(r'vm\.createSelectFork\("([^"]+)"', content)
    chain = None
    if chain_match:
        chain_name = chain_match.group(1)
        # Handle the special case for mainnet (ETH)
        chain = 'ethereum' if chain_name == 'mainnet' else chain_name
        
    return contracts, chain

def get_implementation_address(contract_address, chain):
    """Check if contract is a proxy and get implementation address."""
    if chain not in CHAIN_CONFIGS:
        return None
        
    chain_config = CHAIN_CONFIGS[chain]
    
    # Try to get implementation address using cast
    cmd = [
        'cast', 'implementation', contract_address,
        '--rpc-url', chain_config['chain']
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if result.returncode == 0 and result.stdout.strip():
            impl_address = result.stdout.strip()
            # Check if it's a valid address and not zero address
            if impl_address.startswith('0x') and impl_address != '0x0000000000000000000000000000000000000000':
                print(f"  Detected proxy contract. Implementation address: {impl_address}")
                return impl_address
    except Exception as e:
        print(f"  Note: Could not check for proxy implementation: {e}")
    
    return None

def get_source_code(contract_info, chain, output_dir):
    """Get source code for a contract using cast."""
    if chain not in CHAIN_CONFIGS:
        print(f"Unsupported chain: {chain}")
        return False
        
    chain_config = CHAIN_CONFIGS[chain]
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Check if this is a proxy contract
    original_address = contract_info['ca']
    impl_address = get_implementation_address(original_address, chain)
    
    # Use implementation address if it's a proxy, otherwise use original
    target_address = impl_address if impl_address else original_address
    address_suffix = f"_impl_{impl_address}" if impl_address else f"_{original_address}"
    
    # Construct output filename
    output_file = os.path.join(output_dir, f"{contract_info['name']}{address_suffix}.sol")
    
    # Construct cast command
    cmd = [
        'cast', 'et', target_address,
        '--etherscan-api-key', chain_config['api_key'],
        '-c', chain_config['chain'],
        '--flatten'
    ]
    
    if impl_address:
        print(f"Fetching implementation contract source code from {target_address}")
    print(f"Executing command: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            with open(output_file, 'w') as f:
                f.write(result.stdout)
            print(f"Successfully saved source code to {output_file}")
            return True
        else:
            print(f"Error getting source code: {result.stderr}")
            return False
    except Exception as e:
        print(f"Error running cast command: {e}")
        return False

def main():
    # Use current working directory instead of hardcoded path
    current_dir = Path.cwd()
    test_dir = current_dir / "src" / "test"
    
    # Check if test directory exists
    if not test_dir.exists():
        print(f"Test directory not found: {test_dir}")
        print("Looking for alternative test directory structures...")
        
        # Try alternative locations
        alternative_paths = [
            current_dir / "test",
            current_dir / "src",
            current_dir / "contracts",
        ]
        
        for alt_path in alternative_paths:
            if alt_path.exists():
                print(f"Found alternative directory: {alt_path}")
                test_dir = alt_path
                break
        else:
            print("No test directory found. Please run this script from the DeFiHackLabs root directory.")
            return
    
    # Get all year-month directories (e.g., 2024-01)
    test_dirs = [d for d in test_dir.iterdir() if d.is_dir() and re.match(r'20\d{2}-\d{2}', d.name)]
    test_dirs.sort(reverse=True)  # Sort by time descending
    
    for dir_path in test_dirs:
        print(f"\nProcessing directory: {dir_path}")
        
        # Process each test file in the directory
        for test_file in dir_path.glob('*.sol'):
            print(f"\nProcessing file: {test_file.name}")
            
            # Extract contract addresses, names and chain
            contracts, chain = extract_contract_info(test_file)
            
            if not contracts or not chain:
                print(f"Could not extract contract info or chain from {test_file.name}")
                continue
            
            print(f"Found {len(contracts)} contracts:")
            for contract in contracts:
                print(f"  Name: {contract['name']}, Address: {contract['ca']}")
            print(f"Chain: {chain}")
            
            # Create output directory path using current directory
            output_dir = current_dir / "source" / dir_path.name / test_file.stem
            output_dir.mkdir(parents=True, exist_ok=True)
            
            # Copy the test file to the output directory
            test_file_dest = output_dir / test_file.name
            shutil.copy2(test_file, test_file_dest)
            print(f"Copied test file to {test_file_dest}")
            
            # Get source code for each contract
            for contract in contracts:
                get_source_code(contract, chain, str(output_dir))

if __name__ == "__main__":
    main() 