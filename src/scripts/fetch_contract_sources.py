import os
import re
import subprocess
from datetime import datetime
from pathlib import Path

# API Keys and chain configurations from PRD
CHAIN_CONFIGS = {
    'ethereum': {
        'api_key': 'VI1Q4M1M6XP2M5B648UIYR3JNVFE47KQW7',
        'chain': 'mainnet',
        'api_url': 'https://api.etherscan.io/api'
    },
    'bsc': {
        'api_key': 'GSWUVKIT9HZ28Y9TQEA1VZ6GH5S21MV812',
        'chain': 'bsc',
        'api_url': 'https://api.bscscan.com/api'
    },
    'polygon': {
        'api_key': '661P25T9WH169UD5VWIIG3SYX7E6XVJ2VK',
        'chain': 'polygon',
        'api_url': 'https://api.polygonscan.com/api'
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

def extract_contract_address(text):
    """Extract contract address from text using regex."""
    # Match Ethereum addresses (0x followed by 40 hex characters)
    address_pattern = r'0x[a-fA-F0-9]{40}'
    matches = re.findall(address_pattern, text)
    return matches[0] if matches else None

def determine_chain(file_content):
    """Determine the chain from file content."""
    # Look for chain-specific patterns in the file
    chain_patterns = {
        'bsc': r'bsc|binance',
        'ethereum': r'ethereum|mainnet',
        'polygon': r'polygon|matic',
        'base': r'base',
        'linea': r'linea',
        'arbitrum': r'arbitrum',
        'scroll': r'scroll',
        'optimism': r'optimism',
        'opbnb': r'opbnb',
        'taiko': r'taiko',
        'mantle': r'mantle',
        'fantom': r'fantom',
        'blast': r'blast',
        'xlayer': r'xlayer'
    }
    
    for chain, pattern in chain_patterns.items():
        if re.search(pattern, file_content, re.IGNORECASE):
            return chain
    return 'ethereum'  # Default to ethereum if no chain is specified

def fetch_contract_source(address, chain_config, output_file):
    """Fetch contract source code using cast command."""
    try:
        cmd = [
            'cast', 'et', address,
            '--etherscan-api-key', chain_config['api_key'],
            '-c', chain_config['chain'],
            '--flatten'
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            with open(output_file, 'w') as f:
                f.write(result.stdout)
            print(f"Successfully fetched source for {address} to {output_file}")
        else:
            print(f"Error fetching source for {address}: {result.stderr}")
    except Exception as e:
        print(f"Exception while fetching source for {address}: {str(e)}")

def process_test_files():
    """Process all test files in chronological order."""
    test_dir = Path('/home/comcat/dev/DeFiHackLabs/src/test')
    output_base = Path('/home/comcat/dev/DeFiHackLabs/source')
    
    # Get all test files sorted by modification time (newest first)
    test_files = []
    for root, _, files in os.walk(test_dir):
        for file in files:
            if file.endswith('.sol'):
                file_path = Path(root) / file
                test_files.append((file_path, os.path.getmtime(file_path)))
    
    test_files.sort(key=lambda x: x[1], reverse=True)
    
    for test_file, _ in test_files:
        try:
            with open(test_file, 'r') as f:
                content = f.read()
            
            address = extract_contract_address(content)
            if not address:
                print(f"No contract address found in {test_file}")
                continue
            
            chain = determine_chain(content)
            if chain not in CHAIN_CONFIGS:
                print(f"Unsupported chain {chain} in {test_file}")
                continue
            
            # Create output directory structure
            date_str = datetime.now().strftime('%Y-%m-%d')
            output_dir = output_base / date_str
            output_dir.mkdir(parents=True, exist_ok=True)
            
            # Create output file path
            output_file = output_dir / f"{test_file.stem}.sol"
            
            # Fetch contract source
            fetch_contract_source(address, CHAIN_CONFIGS[chain], output_file)
            
        except Exception as e:
            print(f"Error processing {test_file}: {str(e)}")

if __name__ == "__main__":
    process_test_files() 