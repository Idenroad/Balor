#!/usr/bin/env python3
"""
PMF (Protected Management Frames) Scanner
Détecte si les AP environnants utilisent PMF/802.11w

Usage: sudo python3 pmf_scanner.py -i wlan0

By: idenroad
For: Balor Framework
"""

import subprocess
import re
import argparse
import sys

# Terminal colors
RESET = "\033[0m"
BOLD = "\033[1m"
RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
CYAN = "\033[36m"


def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='Scan for WiFi Access Points and detect PMF/802.11w support - Balor Framework/idenroad'
    )
    parser.add_argument(
        '-i', '--interface',
        default='wlan0',
        help='WiFi interface to use (default: wlan0)'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Show detailed RSN information'
    )
    return parser.parse_args()


def scan_wifi(interface):
    """Scan for WiFi networks using iw"""
    try:
        # Run iw scan
        result = subprocess.run(
            ['iw', 'dev', interface, 'scan'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode != 0:
            print(f"{RED}Error: Unable to scan. Run as root (sudo){RESET}")
            sys.exit(1)
            
        return result.stdout
        
    except subprocess.TimeoutExpired:
        print(f"{RED}Error: Scan timeout{RESET}")
        sys.exit(1)
    except FileNotFoundError:
        print(f"{RED}Error: 'iw' command not found. Install with: sudo apt install iw{RESET}")
        sys.exit(1)


def parse_scan_results(scan_output, verbose=False):
    """Parse iw scan output and extract PMF information"""
    
    networks = []
    current_network = {}
    
    lines = scan_output.split('\n')
    
    for line in lines:
        # New BSS (Access Point)
        if line.startswith('BSS '):
            if current_network:
                networks.append(current_network)
            bssid = line.split()[1].rstrip('(')
            current_network = {
                'bssid': bssid,
                'ssid': None,
                'channel': None,
                'signal': None,
                'security': 'Open',
                'pmf_capable': False,
                'pmf_required': False,
                'wpa_version': None
            }
        
        # SSID
        elif 'SSID:' in line:
            ssid = line.split('SSID:')[1].strip()
            if ssid and current_network:
                current_network['ssid'] = ssid
        
        # Channel
        elif 'DS Parameter set: channel' in line:
            channel = line.split('channel')[1].strip()
            if current_network:
                current_network['channel'] = channel
        
        # Signal strength
        elif 'signal:' in line:
            signal = line.split('signal:')[1].strip().split()[0]
            if current_network:
                current_network['signal'] = signal
        
        # WPA version
        elif 'WPA:' in line:
            if current_network:
                current_network['wpa_version'] = 'WPA'
                current_network['security'] = 'WPA'
        
        elif 'RSN:' in line:
            if current_network:
                current_network['wpa_version'] = 'WPA2/WPA3'
                current_network['security'] = 'WPA2/WPA3'
        
        # PMF Capabilities
        elif 'RSN capabilities:' in line or 'capabilities:' in line:
            # Look for MFP in the capabilities
            if 'MFP-capable' in line or 'MFPC' in line:
                if current_network:
                    current_network['pmf_capable'] = True
            
            if 'MFP-required' in line or 'MFPR' in line:
                if current_network:
                    current_network['pmf_required'] = True
        
        # Explicit Group mgmt cipher suite
        elif 'Group mgmt cipher suite:' in line:
            if current_network:
                current_network['pmf_capable'] = True
    
    # Add last network
    if current_network:
        networks.append(current_network)
    
    return networks


def get_pmf_status(network):
    """Determine PMF status and return colored string"""
    if network['pmf_required']:
        return f"{GREEN}✓ Required{RESET}", "🔒"
    elif network['pmf_capable']:
        return f"{YELLOW}⚠ Optional{RESET}", "🔓"
    else:
        return f"{RED}✗ Disabled{RESET}", "❌"


def display_results(networks, verbose=False):
    """Display scan results with PMF information"""
    
    if not networks:
        print(f"{YELLOW}No networks found{RESET}")
        return
    
    print(f"\n{BOLD}{CYAN}{'='*90}{RESET}")
    print(f"{BOLD}{CYAN}PMF/802.11w Scanner Results{RESET}")
    print(f"{BOLD}{CYAN}{'='*90}{RESET}\n")
    
    # Header
    print(f"{BOLD}{'SSID':<32} {'BSSID':<17} {'CH':<3} {'Signal':<7} {'Security':<12} {'PMF Status'}{RESET}")
    print(f"{'-'*90}")
    
    # Sort by signal strength
    sorted_networks = sorted(
        networks,
        key=lambda x: float(x['signal'].replace(' dBm', '')) if x['signal'] else -100,
        reverse=True
    )
    
    for net in sorted_networks:
        ssid = net['ssid'] or '(Hidden)'
        bssid = net['bssid']
        channel = net['channel'] or '?'
        signal = net['signal'] or '?'
        security = net['security']
        pmf_status, icon = get_pmf_status(net)
        
        print(f"{ssid:<32} {bssid:<17} {channel:<3} {signal:<7} {security:<12} {icon} {pmf_status}")
        
        if verbose and (net['pmf_capable'] or net['pmf_required']):
            print(f"  {BLUE}└─ MFPC={1 if net['pmf_capable'] else 0}, "
                  f"MFPR={1 if net['pmf_required'] else 0}{RESET}")
    
    # Statistics
    total = len(sorted_networks)
    pmf_required = sum(1 for n in sorted_networks if n['pmf_required'])
    pmf_optional = sum(1 for n in sorted_networks if n['pmf_capable'] and not n['pmf_required'])
    no_pmf = total - pmf_required - pmf_optional
    
    print(f"\n{BOLD}Statistics:{RESET}")
    print(f"  Total APs: {total}")
    print(f"  {GREEN}PMF Required (WPA3): {pmf_required}{RESET}")
    print(f"  {YELLOW}PMF Optional: {pmf_optional}{RESET}")
    print(f"  {RED}No PMF: {no_pmf}{RESET}")
    
    print(f"\n{BOLD}Legend:{RESET}")
    print(f"  🔒 {GREEN}Required{RESET}  - WPA3 or WPA2 with mandatory PMF")
    print(f"  🔓 {YELLOW}Optional{RESET}  - WPA2 with optional PMF")
    print(f"  ❌ {RED}Disabled{RESET}  - No PMF protection (vulnerable)")


def main():
    """Main function"""
    args = parse_args()
    
    print(f"{CYAN}Scanning on interface {args.interface}...{RESET}")
    
    scan_output = scan_wifi(args.interface)
    networks = parse_scan_results(scan_output, args.verbose)
    display_results(networks, args.verbose)
    
    print(f"\n{BOLD}Note:{RESET} PMF protects management frames from spoofing/injection attacks")
    print(f"WPA3 requires PMF. Modern WPA2 should have PMF optional or required.\n")


if __name__ == '__main__':
    main()
