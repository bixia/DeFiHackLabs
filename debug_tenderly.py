#!/usr/bin/env python3
"""
Debug script for Tenderly API calls
"""

import requests
import json
from pathlib import Path

# Tenderly API configuration
TENDERLY_BASE_URL = "https://api.tenderly.co/api/v1/explorer"
TENDERLY_AUTH_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2NvdW50X2lkIjoiNTY3YWQ1ZTEtYzUxNi00NWI1LWI5YmYtZDQ1MWFhYzYzZGMzIiwic2Vzc2lvbl9ub25jZSI6NiwidmFsaWRfdG8iOjE3NDM4NDE2NjV9.9pR6SJomb9vk6c70wSRvBB5t3SdYext9h-hE0X2Eo2g"

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

def test_tenderly_endpoints():
    """Test different Tenderly API endpoints"""
    
    # Test transaction hash
    tx_hash = "0x729c502a7dfd5332a9bdbcacec97137899ecc82c17d0797b9686a7f9f6005cb7"
    
    print(f"🔍 Testing Tenderly API endpoints for {tx_hash}")
    print("=" * 80)
    
    # Endpoint 1: Basic explorer endpoint (current one)
    print("\n1️⃣ Testing basic explorer endpoint:")
    url1 = f"{TENDERLY_BASE_URL}/{tx_hash}"
    print(f"URL: {url1}")
    
    try:
        response1 = requests.get(url1, headers=TENDERLY_HEADERS, timeout=30)
        print(f"Status: {response1.status_code}")
        
        if response1.status_code in [200, 202]:
            data1 = response1.json()
            print(f"Keys in response: {list(data1.keys())}")
            
            # Check if this has trace/call data
            if 'calls' in data1:
                print(f"✅ Has 'calls' field with {len(data1['calls'])} calls")
            elif 'trace' in data1:
                print(f"✅ Has 'trace' field")
            else:
                print("❌ No trace/call data found in response")
                print(f"Sample data: {json.dumps(data1, indent=2)[:500]}...")
        else:
            print(f"❌ Error: {response1.text}")
    except Exception as e:
        print(f"❌ Exception: {e}")
    
    # Endpoint 2: Try trace endpoint
    print("\n2️⃣ Testing trace endpoint:")
    url2 = f"{TENDERLY_BASE_URL}/{tx_hash}/trace"
    print(f"URL: {url2}")
    
    try:
        response2 = requests.get(url2, headers=TENDERLY_HEADERS, timeout=30)
        print(f"Status: {response2.status_code}")
        
        if response2.status_code in [200, 202]:
            data2 = response2.json()
            print(f"Keys in response: {list(data2.keys())}")
            print(f"Sample data: {json.dumps(data2, indent=2)[:500]}...")
        else:
            print(f"❌ Error: {response2.text}")
    except Exception as e:
        print(f"❌ Exception: {e}")
    
    # Endpoint 3: Try calls endpoint
    print("\n3️⃣ Testing calls endpoint:")
    url3 = f"{TENDERLY_BASE_URL}/{tx_hash}/calls"
    print(f"URL: {url3}")
    
    try:
        response3 = requests.get(url3, headers=TENDERLY_HEADERS, timeout=30)
        print(f"Status: {response3.status_code}")
        
        if response3.status_code in [200, 202]:
            data3 = response3.json()
            print(f"Keys in response: {list(data3.keys())}")
            print(f"Sample data: {json.dumps(data3, indent=2)[:500]}...")
        else:
            print(f"❌ Error: {response3.text}")
    except Exception as e:
        print(f"❌ Exception: {e}")
    
    # Endpoint 4: Try different format
    print("\n4️⃣ Testing different API format:")
    url4 = f"https://api.tenderly.co/api/v1/public-contracts/trace/{tx_hash}"
    print(f"URL: {url4}")
    
    try:
        response4 = requests.get(url4, headers=TENDERLY_HEADERS, timeout=30)
        print(f"Status: {response4.status_code}")
        
        if response4.status_code in [200, 202]:
            data4 = response4.json()
            print(f"Keys in response: {list(data4.keys())}")
            print(f"Sample data: {json.dumps(data4, indent=2)[:500]}...")
        else:
            print(f"❌ Error: {response4.text}")
    except Exception as e:
        print(f"❌ Exception: {e}")

def check_response_structure():
    """Check the actual structure of what we're getting"""
    tx_hash = "0x729c502a7dfd5332a9bdbcacec97137899ecc82c17d0797b9686a7f9f6005cb7"
    url = f"{TENDERLY_BASE_URL}/{tx_hash}"
    
    print(f"\n🔍 Detailed structure analysis for: {url}")
    print("=" * 80)
    
    try:
        response = requests.get(url, headers=TENDERLY_HEADERS, timeout=30)
        
        if response.status_code in [200, 202]:
            data = response.json()
            
            print(f"📊 Response Analysis:")
            print(f"- Status Code: {response.status_code}")
            print(f"- Content Length: {len(response.text)} characters")
            print(f"- JSON Keys: {len(data.keys())} total")
            
            print(f"\n📋 All available keys:")
            for i, key in enumerate(sorted(data.keys()), 1):
                value = data[key]
                if isinstance(value, list):
                    print(f"  {i:2d}. {key}: List with {len(value)} items")
                elif isinstance(value, dict):
                    print(f"  {i:2d}. {key}: Dict with {len(value)} keys")
                else:
                    print(f"  {i:2d}. {key}: {type(value).__name__} - {str(value)[:50]}...")
            
            # Check for trace-like data
            print(f"\n🔍 Looking for trace data...")
            trace_fields = ['calls', 'trace', 'logs', 'internal_transactions', 'events']
            for field in trace_fields:
                if field in data:
                    print(f"✅ Found '{field}': {type(data[field]).__name__}")
                    if isinstance(data[field], list):
                        print(f"    Items: {len(data[field])}")
                        if data[field]:
                            print(f"    Sample item keys: {list(data[field][0].keys()) if isinstance(data[field][0], dict) else 'Not dict'}")
                else:
                    print(f"❌ No '{field}' field")
            
            # Show sample of the full response
            print(f"\n📄 Sample response (first 1000 chars):")
            print("-" * 50)
            print(json.dumps(data, indent=2)[:1000] + "...")
            
        else:
            print(f"❌ Failed with status {response.status_code}")
            print(f"Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Exception: {e}")

if __name__ == "__main__":
    test_tenderly_endpoints()
    check_response_structure() 