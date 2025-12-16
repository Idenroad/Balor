# balorsh wifi - WiFi Stack Commands Reference

[Version française](balorsh_wifi_fr.md)

This document describes all menu options available in the WiFi stack of balorsh (v0.6).

## Table of Contents

- [Interface Control](#interface-control)
- [Reconnaissance](#reconnaissance)
- [Attacks](#attacks)
- [Cracking](#cracking)

---

## Interface Control

### [1] List WiFi interfaces

Displays all available WiFi interfaces detected on the system.

**What it does:**
- Uses `iw dev` to enumerate WiFi interfaces
- Shows interface names (e.g., wlan0, wlan1)
- Indicates if no interfaces are found

**Use case:** Check which WiFi adapters are available before starting any operation.

---

### [2] Select WiFi interface and enable monitor mode

Prompts you to select a WiFi interface and activates monitor mode on it.

**What it does:**
- Lists available WiFi interfaces
- Asks you to choose one (with a default suggestion)
- Activates monitor mode using `airmon-ng` or `iw`/`iwconfig`
- Kills conflicting processes (NetworkManager, wpa_supplicant)
- Verifies that monitor mode is properly enabled

**Use case:** Required before most WiFi attacks (packet capture, deauth, etc.).

**Note:** This will temporarily disable your normal WiFi connection on this interface.

---

### [3] Disable monitor mode on interface

Disables monitor mode and returns the interface to managed mode.

**What it does:**
- Prompts for interface selection
- Stops monitor mode using `airmon-ng` or `iw`/`iwconfig`
- Restores the interface to managed mode
- Allows normal WiFi connectivity again

**Use case:** When you're done with attacks and want to restore normal WiFi functionality.

---

### [4] Channel hopping

Cycles through WiFi channels 1-11 continuously.

**What it does:**
- Switches the selected interface through channels 1 to 11
- Updates every ~0.3 seconds
- Displays current channel in real-time
- Runs until you press Ctrl+C

**Use case:** Useful for passive monitoring or when you want to capture traffic across multiple channels.

---

## Reconnaissance

### [5] WiFi Scan (airodump-ng)

Launches airodump-ng to scan for nearby WiFi networks.

**What it does:**
- Starts airodump-ng on the selected interface (must be in monitor mode)
- Displays nearby access points (BSSID, channel, encryption, ESSID)
- Shows connected clients
- Updates in real-time

**Use case:** Discover available WiFi networks, their channels, encryption types, and connected clients.

**Tip:** Press Ctrl+C to stop the scan.

---

### [6] Automatic attack (wifite)

Launches wifite for automated WiFi attacks.

**What it does:**
- Automatically scans for WiFi networks
- Attempts various attacks (WEP, WPA handshake capture, WPS)
- Uses rockyou.txt wordlist if available
- Saves captures in `/opt/balorsh/data/wifi_wifite/hs/`
- Kills conflicting processes automatically

**Use case:** Fully automated WiFi pentesting - good for beginners or quick assessments.

---

### [7] Bettercap reconnaissance

Launches bettercap for WiFi reconnaissance.

**What it does:**
- Starts bettercap on the selected interface
- Enables WiFi reconnaissance module
- Enables channel hopping
- Displays discovered networks and clients
- Updates automatically every second

**Use case:** Advanced WiFi reconnaissance with scripting capabilities.

---

### [8] PMF Scanner (Protected Management Frames)

Scans WiFi networks to detect if PMF (Protected Management Frames) is enabled.

**What it does:**
- Uses the integrated `pmf_scanner.py` script
- Scans all available WiFi networks
- Displays the status of PMF for each network
- Displays ESSID, BSSID, and PMF status (Required, Optional, Disabled)

**Use case:** Identify networks vulnerable to deauthentication attacks (PMF disabled) or those protected against such attacks (PMF enabled).

---

### [9] Deauth attack (aireplay-ng)

Performs deauthentication attacks to disconnect clients from an access point.

**What it does:**
- Asks for target BSSID (access point MAC address)
- Optionally asks for client MAC (or targets all clients)
- Asks for number of deauth packets to send
- Sends deauthentication frames using aireplay-ng

**Use case:**
- Disconnect clients from an AP (DoS)
- Force clients to reconnect (to capture handshakes)

**Warning:** This is a denial-of-service attack. Only use on authorized networks.

---

### [10] WPS attack (reaver, bully, pixie dust)

Attempts to crack WPS PIN to recover the WiFi password.

**What it does:**
- Prompts for target BSSID and channel
- Offers three attack methods:
  1. **Reaver** - Brute force WPS PIN
  2. **Bully** - Alternative WPS cracking tool
  3. **Pixie Dust** - Exploits weak WPS implementations

**Use case:** Attack WPS-enabled routers to recover the WiFi password.

**Note:** WPS must be enabled on the target AP. Pixie dust is the fastest but only works on vulnerable routers.

---

### [11] Capture handshake

Captures WPA/WPA2 4-way handshakes for offline cracking.

**What it does:**
- Asks for target BSSID and channel
- Starts airodump-ng focused on that specific AP
- Captures traffic until a handshake is obtained
- Saves capture files in `/opt/balorsh/data/wifi_captures/`
- Creates multiple file formats (.cap, .csv, .kismet files)

**Use case:** Capture handshakes for later offline cracking with aircrack-ng or hashcat.

**Tip:** You may need to deauth clients (option 8) to force a handshake.

---

## Cracking

### [12] Crack with aircrack-ng

Cracks captured handshakes using aircrack-ng and a wordlist.

**What it does:**
- Asks for the capture file (.cap)
- Provides interactive wordlist selection (rockyou, custom, etc.)
- Can concatenate multiple wordlists
- Launches aircrack-ng with the selected wordlist
- Displays the password if found

**Use case:** Crack WPA/WPA2 handshakes using dictionary attacks.

---

### [13] Crack with hashcat

Cracks handshakes using hashcat (GPU-accelerated).

**What it does:**
- Asks for hash file (.hc22000 format)
- Provides interactive wordlist selection
- Prepares and concatenates wordlists if needed
- Launches hashcat in mode 22000 (WPA-PBKDF2-PMKID+EAPOL)
- Shows real-time status every 15 seconds

**Use case:** Fast GPU-based cracking of WiFi handshakes.

**Note:** Requires a compatible GPU and proper hashcat installation.

---

### [14] Convert handshake to hashcat format

Converts .cap files to hashcat-compatible .hc22000 format.

**What it does:**
- Asks for source .cap or .pcapng file
- Uses hcxpcapngtool to convert the capture
- Creates .hc22000 file compatible with hashcat
- Generates metadata file with capture information

**Use case:** Prepare captures for hashcat cracking.

---

### [15] Auto-capture (handshake/PMKID)

Automatically captures handshakes and PMKID using hcxdumptool.

**What it does:**
- Uses hcxdumptool for advanced capture (PMKID + EAPOL)
- Automatically converts to hashcat format (.hc22000)
- Falls back to airodump-ng if hcxdumptool is unavailable
- Saves all files in `/opt/balorsh/data/wifi_captures/`
- Creates metadata files for tracking

**Use case:** Modern, efficient way to capture crackable hashes from WiFi networks.

**Advantage:** Can capture PMKID without deauth (clientless attack).

---

### [16] Capture PMKID (hcxdumptool)

Specifically captures PMKID from access points.

**What it does:**
- Uses hcxdumptool to capture PMKID
- Works without connected clients (clientless attack)
- Automatically converts to hashcat format
- Saves capture and hash files

**Use case:** Capture WiFi credentials without waiting for clients to connect.

**Note:** Not all routers are vulnerable to PMKID attacks (mostly older WPA2 implementations).

---

### [17] Session management (start/end)

Manages capture sessions for better organization.

**What it does:**
- **Start session:** Creates a timestamped directory for organizing captures
- **End session:** Closes the current session and saves metadata
- Helps keep track of multiple pentesting sessions

**Use case:** Organize captures from different pentesting engagements.

---

### [18] Select target (TUI)

Interactive target selection using fzf (fuzzy finder).

**What it does:**
- Performs a quick 6-second scan
- Displays results in an interactive menu
- Shows BSSID, channel, and ESSID
- Allows arrow-key selection

**Use case:** Easier target selection without manually typing MAC addresses.

**Requirement:** Requires `fzf` to be installed.

---

### [19] Bruteforce

Performs mask-based bruteforce attacks with hashcat.

**What it does:**
- Asks for hash file (.hc22000)
- Lets you choose character set (lowercase, uppercase, digits, custom)
- Asks for min/max password length
- Can exclude known passwords (like rockyou.txt)
- Iterates through all password lengths

**Use case:** Bruteforce short passwords when dictionary attacks fail.

**Warning:** Very time-consuming. Only practical for short passwords (8-10 characters max).

---

### [20] Random MAC address

Changes the MAC address of the selected interface.

**What it does:**
- Generates a random MAC address
- Changes the interface MAC using `macchanger`
- Useful for anonymity

**Use case:** Bypass MAC filtering or remain anonymous during attacks.

---

### [21] Cleanup old captures

Removes old capture files to free disk space.

**What it does:**
- Asks for age threshold (in days)
- Finds and deletes files older than specified days
- Targets `/opt/balorsh/data/wifi_*` directories
- Shows count of deleted files

**Use case:** Clean up disk space after pentesting sessions.

---

### [22] Adaptive channel hopping

Smart channel hopping that focuses on active channels.

**What it does:**
- Performs a quick scan to detect active channels
- Hops only through channels with detected APs
- More efficient than simple channel hopping

**Use case:** Better reconnaissance on busy networks.

---

### [23] Help

Displays comprehensive help information about the WiFi stack.

**What it does:**
- Shows tool descriptions
- Explains common workflows
- Lists file locations
- Provides usage tips

**Use case:** Quick reference when you need help.

---

### [24] Restart NetworkManager

Restarts NetworkManager service.

**What it does:**
- Restarts the NetworkManager systemd service
- Useful when WiFi gets stuck after monitor mode
- Restores normal network functionality

**Use case:** Fix WiFi connectivity issues after pentesting.

---

### [0] Return

Exits the WiFi stack menu and returns to the main balorsh menu.

---

## File Locations

All WiFi stack files are stored in:

```
/opt/balorsh/data/
├── wifi_captures/       # Handshake captures
├── wifi_wifite/         # Wifite results
│   └── hs/             # Wifite handshakes
└── wifi_sessions/       # Session-based captures
```

---

## Tips

1. **Always use a dedicated WiFi adapter** - Don't use your main system WiFi for attacks
2. **Check monitor mode** - Most attacks require monitor mode (option 2)
3. **Use option 22 for help** - Comprehensive help is available in the menu
4. **Restart NetworkManager** - Use option 23 if WiFi gets stuck
5. **Start with airodump-ng** - Option 5 is great for reconnaissance
6. **Auto-capture is recommended** - Option 14 is the most efficient capture method

---

## Legal Notice

Only use these tools on networks you own or have explicit written permission to test.
Unauthorized access to computer networks is illegal in most jurisdictions.

---

**Documentation version:** 0.6  
**Last updated:** December 2025
