# balorsh networkscan - Network Scan Stack Commands Reference

[Version française](balorsh_networkscan_fr.md)

This document describes all menu options available in the Network Scanner stack of balorsh (v0.7).

## Table of Contents

- [Network Discovery](#network-discovery)
- [Nmap Scans](#nmap-scans)
- [Masscan Scans](#masscan-scans)
- [Capture & Analysis](#capture--analysis)
- [Utilities](#utilities)

---

## Network Discovery

### [1] Display network interfaces

Shows all available network interfaces on the system with their status.

**What it does:**
- Lists all network interfaces using `ip -br addr`
- Shows interface name, state (UP/DOWN), and IP address
- Color-codes active (green) and inactive (red) interfaces

**Use case:** Check which network interfaces are available before starting scans.

**Output example:**
```
● eth0 - UP - 192.168.1.100/24
● wlan0 - DOWN - 
● lo - UNKNOWN - 127.0.0.1/8
```

---

### [2] Quick local network detection

Automatically detects and scans your local network.

**What it does:**
- Detects your default network interface
- Extracts your local IP address
- Calculates the network range (e.g., 192.168.1.0/24)
- Performs a quick nmap ping scan (`-sn`)
- Saves results to `/opt/balorsh/data/networkscan/nmap/quick_local_*.txt`

**Use case:** Quickly discover all active hosts on your local network without manual configuration.

**Output:** List of active hosts with their IP addresses and MAC addresses (if available).

---

### [3] Local ARP scan (arp-scan)

Performs ARP-based host discovery on the local network.

**What it does:**
- Asks you to select a network interface
- Uses `arp-scan` to send ARP requests
- Discovers all hosts on the local network segment
- Shows IP, MAC address, and vendor information
- Saves results to `/opt/balorsh/data/networkscan/arpscan/scan_*.txt`

**Use case:** Fast and reliable local network discovery (Layer 2).

**Advantages:**
- Very fast (no TCP/UDP overhead)
- Works even with strict firewalls
- Only works on local network segment

**Note:** Requires root privileges and only works on local networks.

---

### [4] Netdiscover passive

Passive network discovery using netdiscover in sniffing mode.

**What it does:**
- Asks for target network range (e.g., 192.168.1.0/24)
- Asks for network interface
- Runs netdiscover in passive mode (sniffing only)
- Captures ARP traffic for 60 seconds
- Saves discovered hosts to `/opt/balorsh/data/networkscan/netdiscover/passive_*.txt`

**Use case:** Stealthy network reconnaissance without sending packets.

**Advantages:**
- Completely passive (no packets sent)
- Cannot be detected
- Good for sensitive environments

**Limitation:** Only discovers hosts that are actively communicating.

---

### [5] Netdiscover active

Active network discovery using netdiscover.

**What it does:**
- Asks for target network range
- Asks for network interface
- Sends ARP requests to discover hosts
- Shows real-time results as hosts are discovered
- Saves results to `/opt/balorsh/data/networkscan/netdiscover/active_*.txt`

**Use case:** Active network discovery on local networks.

**Advantages:**
- Discovers all hosts (even quiet ones)
- Faster than passive mode
- Real-time display

**Note:** This sends packets and can be detected.

---

## Nmap Scans

### [6] Quick scan (top 100 ports)

Fast nmap scan of the most common 100 ports.

**What it does:**
- Asks for target IP or network range
- Validates the target format
- Scans top 100 ports using `nmap -F -T4`
- Saves results in both text and XML formats
- Location: `/opt/balorsh/data/networkscan/nmap/quick_*.txt/xml`

**Use case:** Quick initial scan to identify open services.

**Scan time:** Usually 1-5 seconds per host.

**Target formats accepted:**
- Single IP: `192.168.1.100`
- CIDR notation: `192.168.1.0/24`
- IP range: `192.168.1.1-254`

---

### [7] Full scan (all ports)

Comprehensive nmap scan of all 65535 ports.

**What it does:**
- Asks for target IP or network range
- Scans all TCP ports using `nmap -p- -T4`
- Saves results in text and XML formats
- Location: `/opt/balorsh/data/networkscan/nmap/full_*.txt/xml`

**Use case:** Thorough port scanning when you need complete coverage.

**Warning:** This scan can take a long time (minutes to hours depending on target).

**Scan time:** 
- Single host: 5-20 minutes
- /24 network: hours

---

### [8] Service and version scan

Detects running services, versions, and operating system.

**What it does:**
- Asks for target IP or network range
- Performs service version detection (`-sV`)
- Runs default NSE scripts (`-sC`)
- Attempts OS detection (`-O`)
- Saves detailed results in text and XML
- Location: `/opt/balorsh/data/networkscan/nmap/services_*.txt/xml`

**Use case:** Identify specific services, versions, and OS for vulnerability assessment.

**Output includes:**
- Service names (e.g., Apache, SSH, MySQL)
- Version numbers (e.g., OpenSSH 8.2p1)
- OS detection (e.g., Linux 5.x)
- NSE script results (banners, SSL info, etc.)

---

### [9] Stealth scan (SYN)

Stealthy SYN scan that doesn't complete TCP connections.

**What it does:**
- Asks for target IP or network range
- Performs SYN stealth scan (`nmap -sS -T2`)
- Uses slower timing template for stealth
- Saves results in text and XML
- Location: `/opt/balorsh/data/networkscan/nmap/stealth_*.txt/xml`

**Use case:** Scan targets while minimizing detection risk.

**Advantages:**
- Doesn't complete TCP handshake
- Less likely to be logged
- Quieter than full connect scans

**Note:** Requires root privileges.

---

### [10] Vulnerability scan (NSE)

Runs nmap NSE vulnerability detection scripts.

**What it does:**
- Asks for target IP or network range
- Runs vulnerability detection scripts (`--script vuln`)
- Checks for common vulnerabilities (CVEs)
- Saves detailed findings in text and XML
- Location: `/opt/balorsh/data/networkscan/nmap/vuln_*.txt/xml`

**Use case:** Automated vulnerability assessment.

**Warning:** This scan can trigger IDS/IPS systems and may be considered aggressive.

**Detected vulnerabilities may include:**
- SQL injection
- XSS vulnerabilities
- SSL/TLS issues
- Known CVEs
- Weak configurations

---

### [11] UDP scan

Scans the top 100 UDP ports.

**What it does:**
- Asks for target IP or network range
- Scans top 100 UDP ports using `nmap -sU --top-ports 100`
- Saves results in text and XML
- Location: `/opt/balorsh/data/networkscan/nmap/udp_*.txt/xml`

**Use case:** Discover UDP services (DNS, SNMP, DHCP, etc.).

**Warning:** UDP scans are notoriously slow due to lack of responses.

**Scan time:** Much slower than TCP scans (can take 20+ minutes).

**Common UDP services:**
- 53 (DNS)
- 161/162 (SNMP)
- 67/68 (DHCP)
- 123 (NTP)

---

## Masscan Scans

### [12] Ultra-fast scan (all ports)

High-speed port scan using masscan.

**What it does:**
- Asks for target IP or network range
- Scans all 65535 ports at 10,000 packets/second
- Uses `masscan -p1-65535 --rate=10000`
- Saves results in text and XML
- Location: `/opt/balorsh/data/networkscan/masscan/fast_*.txt/xml`

**Use case:** Extremely fast scanning of large networks or all ports.

**Advantages:**
- Can scan entire internet ranges in minutes
- Much faster than nmap
- Good for initial port discovery

**Limitations:**
- No service detection
- No version information
- Less reliable than nmap

**Warning:** High packet rate can overwhelm networks or trigger security systems.

---

### [13] Web ports scan

Scans common web service ports using masscan.

**What it does:**
- Asks for target IP or network range
- Scans ports: 80, 443, 8000, 8080, 8443, 3000, 5000, 8888
- Uses rate of 5000 packets/second
- Saves results in text and XML
- Location: `/opt/balorsh/data/networkscan/masscan/web_*.txt/xml`

**Use case:** Quickly find web servers and services.

**Target ports:**
- 80, 443: Standard HTTP/HTTPS
- 8000, 8080: Alternative HTTP
- 8443: Alternative HTTPS
- 3000: Node.js/React dev
- 5000: Flask dev
- 8888: Jupyter/alternative HTTP

---

## Capture & Analysis

### [14] Tcpdump capture (to file)

Captures network traffic to a pcap file.

**What it does:**
- Asks for network interface
- Asks for optional BPF filter (e.g., `port 80`, `host 192.168.1.1`)
- Captures packets to pcap file
- Automatically generates a summary text file
- Location: `/opt/balorsh/data/networkscan/tcpdump/capture_*.pcap`

**Use case:** Capture network traffic for later analysis.

**BPF filter examples:**
- `port 80` - Only HTTP traffic
- `host 192.168.1.1` - Traffic to/from specific host
- `tcp and port 443` - Only HTTPS traffic
- `icmp` - Only ping traffic

**Output files:**
- `.pcap` - Full packet capture (can be opened in Wireshark)
- `_summary.txt` - Text summary with statistics and first 50 packets

---

### [15] Tcpdump live display

Real-time traffic capture and display.

**What it does:**
- Asks for network interface
- Asks for optional BPF filter
- Displays packets in real-time on screen
- Also saves to text file in background
- Location: `/opt/balorsh/data/networkscan/tcpdump/live_*.txt`

**Use case:** Monitor network traffic in real-time.

**Display includes:**
- Source/destination IPs
- Protocols
- Ports
- Packet sizes
- Flags

**Tip:** Press Ctrl+C to stop capture.

---

### [16] Launch Wireshark

Opens Wireshark for packet analysis.

**What it does:**
- Offers two options:
  1. Launch Wireshark GUI for live capture
  2. Open an existing pcap file
- Starts Wireshark in background

**Use case:** 
- Deep packet analysis
- Protocol dissection
- Traffic visualization

**Advantages of Wireshark:**
- Graphical interface
- Advanced filtering
- Protocol decoding
- Statistical analysis
- Flow graphs

---

## Utilities

### [17] Clean old scans

Removes old scan files to free disk space.

**What it does:**
- Asks for age threshold in days (default: 7)
- Finds all scan files older than threshold
- Deletes files from all networkscan subdirectories
- Shows count of deleted files

**Use case:** Regular cleanup to prevent disk space issues.

**Affected directories:**
- `/opt/balorsh/data/networkscan/nmap/`
- `/opt/balorsh/data/networkscan/masscan/`
- `/opt/balorsh/data/networkscan/arpscan/`
- `/opt/balorsh/data/networkscan/tcpdump/`
- `/opt/balorsh/data/networkscan/netdiscover/`

---

### [18] Help

Displays comprehensive help information.

**What it does:**
- Shows available tools and their purposes
- Explains accepted address formats
- Describes scan types
- Lists file locations
- Provides tips and warnings

**Use case:** Quick reference guide.

**Topics covered:**
- Tool descriptions (nmap, masscan, arp-scan, etc.)
- IP address format validation
- Scan type characteristics
- Best practices
- Legal warnings

---

### [0] Return

Exits the Network Scanner stack menu and returns to the main balorsh menu.

---

## IP Address Validation

The networkscan stack includes robust IP validation that prevents common errors:

**Valid formats:**
- Single IP: `192.168.1.100` ✓
- CIDR: `192.168.1.0/24` ✓
- Range: `192.168.1.1-254` ✓

**Invalid examples (rejected):**
- `256.1.1.1` ✗ (octet > 255)
- `192.168.1.0/33` ✗ (mask > 32)
- `192.168.1.300` ✗ (octet > 255)

The system will show clear error messages and ask you to re-enter valid addresses.

---

## File Locations

All network scan files are stored in:

```
/opt/balorsh/data/networkscan/
├── nmap/           # Nmap scan results
├── masscan/        # Masscan scan results
├── arpscan/        # ARP scan results
├── netdiscover/    # Netdiscover results
└── tcpdump/        # Packet captures
```

Each scan creates timestamped files for easy organization.

---

## Tips & Best Practices

1. **Start with quick scans** - Use option 2 or 6 for initial reconnaissance
2. **Validate targets** - The system validates IP addresses to prevent errors
3. **Use arp-scan for local** - Option 3 is the fastest for local network discovery
4. **Masscan for speed** - Option 12 is ideal for scanning large IP ranges
5. **Nmap for details** - Options 7-11 provide comprehensive information
6. **Save everything** - All scans automatically save to timestamped files
7. **Clean regularly** - Use option 17 to prevent disk space issues
8. **Use filters** - BPF filters in tcpdump help focus on relevant traffic

---

## Scan Comparison

| Tool | Speed | Detail | Use Case |
|------|-------|--------|----------|
| arp-scan | ⚡⚡⚡ | Low | Local network discovery |
| netdiscover | ⚡⚡⚡ | Low | Local host discovery |
| masscan | ⚡⚡⚡ | Low | Fast port scanning |
| nmap quick | ⚡⚡ | Medium | Initial reconnaissance |
| nmap full | ⚡ | High | Complete port coverage |
| nmap services | ⚡ | Very High | Service identification |
| nmap vuln | ⚡ | Very High | Vulnerability assessment |

---

## Legal Notice

**Important:** Only scan networks you own or have explicit written authorization to test.

- ❌ Unauthorized network scanning is illegal in most jurisdictions
- ❌ Can be considered as attempted intrusion
- ✅ Always get written permission before scanning
- ✅ Respect rate limits and avoid DoS conditions

The authors and contributors of Balor/balorsh cannot be held responsible for misuse of these tools.

---

## Common Workflows

### Workflow 1: Local Network Discovery
1. [2] Quick local network detection
2. [3] Local ARP scan for details
3. [6] Quick nmap scan on interesting hosts
4. [8] Service scan for vulnerability assessment

### Workflow 2: External Target Assessment
1. [6] Quick scan to find open ports
2. [8] Service and version detection
3. [10] Vulnerability scan
4. [14] Tcpdump capture for traffic analysis

### Workflow 3: Web Application Discovery
1. [13] Masscan web ports
2. [8] Service scan on discovered hosts
3. [16] Wireshark for HTTP/HTTPS analysis

---

**Documentation version:** 0.7  
**Last updated:** December 2025
