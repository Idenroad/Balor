# Balor Documentation - Remote Access Stack

## Overview

The **Remote Access** stack in Balor provides a comprehensive set of tools for connecting to remote systems via different protocols. It facilitates access to remote machines, network share enumeration, and session management.

This stack supports:
- **SSH** - Secure Shell connections
- **RDP** - Remote Desktop Protocol (Windows)
- **Samba/SMB** - Windows/Linux file shares
- **NFS** - Network File System (Unix/Linux)
- **Remmina** - Graphical remote desktop client
- **Nmap** - Remote access service scanning

## Session Logging

All connection sessions are automatically logged in `/opt/balorsh/data/remoteaccess/` with timestamps:
- SSH sessions → `/opt/balorsh/data/remoteaccess/ssh/`
- RDP sessions → `/opt/balorsh/data/remoteaccess/rdp/`
- SMB sessions → `/opt/balorsh/data/remoteaccess/smb/`
- NFS mounts → `/opt/balorsh/data/remoteaccess/nfs/`

Log file format: `YYYYMMDD_HHMMSS_<host>.log`

---

## Main Menu

### [1] SSH Connection

Connects to a remote server via SSH with password authentication.

**What it does:**
- Asks for remote server IP address/hostname
- Asks for username
- Asks for password (in shadow mode for security)
- Establishes an interactive SSH connection
- Logs the session in `/opt/balorsh/data/remoteaccess/ssh/`

**Tools used:** `sshpass`, `ssh`, `tee`

**Use cases:** 
- Remote Linux/Unix server administration
- Executing commands on remote machines
- File transfers via SCP/SFTP

**Example:**
```bash
IP Address/Hostname: 192.168.1.100
Username: admin
Password: ********
```

**Note:** The session is logged with timestamp for audit and traceability.

---

### [2] RDP Connection

Connects to a remote Windows desktop via Remote Desktop Protocol.

**What it does:**
- Asks for remote Windows server IP address
- Asks for username
- Asks for password (in shadow mode)
- Tries `xfreerdp` first, then falls back to `rdesktop` if unavailable
- Logs the session in `/opt/balorsh/data/remoteaccess/rdp/`

**Tools used:** `xfreerdp` (preferred) or `rdesktop`

**Use cases:** 
- Remote Windows server administration
- Access to graphical Windows applications
- Remote technical support

**Example:**
```bash
IP Address: 192.168.1.200
Username: Administrator
Password: ********
```

**xfreerdp options:**
- `/cert-ignore` - Ignore certificate warnings
- `/dynamic-resolution` - Adaptive resolution
- `/clipboard` - Clipboard sharing

---

### [3] Open Remmina

Launches the Remmina graphical client for RDP/VNC/SSH connections.

**What it does:**
- Checks if Remmina is installed
- Launches the Remmina GUI
- Allows managing multiple connection profiles

**Tools used:** `remmina`

**Use cases:** 
- Centralized management of multiple remote connections
- RDP connections with advanced features (audio, printers)
- VNC connections to Linux/macOS machines

**Remmina features:**
- Multi-protocol support (RDP, VNC, SSH, SPICE)
- Connection profile saving
- Local resource sharing (folders, printers)
- SSH tunneling

---

### [4] Samba/SMB Connection

Connects to Windows/Samba network shares with three different methods.

**What it does:**
- Asks for SMB server IP address/hostname
- Asks for share name
- Asks for username
- Asks for password (in shadow mode)
- Offers 3 connection methods:
  1. **Graphical interface** (nautilus/thunar/dolphin)
  2. **Local mount** (mount.cifs)
  3. **Command-line client** (smbclient)
- Logs the session in `/opt/balorsh/data/remoteaccess/smb/`

**Tools used:** `smbclient`, `mount.cifs`, file managers

**Use cases:** 
- Access Windows shares from Linux
- File transfers to/from Windows servers
- Network share enumeration

**Examples:**
```bash
# Method 1: GUI
Server: 192.168.1.50
Share: Public
User: user1
→ Opens in file manager

# Method 2: Mount
→ Mounts on /mnt/smb_share
→ Accessible as local folder

# Method 3: smbclient
→ Interactive command line
smb: \> ls, get, put, etc.
```

**Note:** Mounting requires sudo privileges.

---

### [5] NFS Mount

Mounts a remote NFS share locally.

**What it does:**
- Asks for NFS server IP address
- Asks for NFS export path
- Asks for local mount point (default: `/mnt/nfs_share`)
- Offers choice of NFS version (3 or 4)
- Mounts the share with appropriate options
- Logs the operation in `/opt/balorsh/data/remoteaccess/nfs/`

**Tools used:** `mount.nfs`, `showmount`

**Use cases:** 
- Access remote Unix/Linux shares
- High-performance file transfers
- Data sharing between Linux servers

**Example:**
```bash
NFS Server IP: 192.168.1.75
NFS Export: /export/data
Mount Point: /mnt/nas_data
NFS Version: 4
```

**Mount options:**
- `rw` - Read/write
- `sync` - Immediate synchronization
- `hard` - Retry on network failure
- `intr` - User-interruptible

**Note:** Requires `sudo` and `nfs-utils` service installed.

---

### [6] Scan Remote Access Services (nmap)

Scans a remote host to detect available remote access services.

**What it does:**
- Asks for IP address or IP range to scan
- Scans remote access service ports:
  - **22** (SSH)
  - **23** (Telnet)
  - **21** (FTP)
  - **139, 445** (SMB/Samba)
  - **3389** (RDP)
  - **5900-5909** (VNC)
  - **2049** (NFS)
  - **873** (rsync)
  - **5985, 5986** (WinRM)
- Detects versions and operating systems
- Displays a comprehensive report of discovered services

**Tools used:** `nmap`

**Use cases:** 
- Network reconnaissance
- Security audit (exposed services)
- Access strategy planning

**Example:**
```bash
IP Address: 192.168.1.0/24

Results:
192.168.1.10 → SSH (22), SMB (445)
192.168.1.20 → RDP (3389)
192.168.1.30 → NFS (2049), SSH (22)
```

**nmap options:**
- `-sV` - Version detection
- `-O` - OS detection
- `-Pn` - Skip ping (assume host up)
- `-T4` - Aggressive timing template

---

### [7] List SMB Shares (enum4linux)

Enumerates available shares on an SMB/Samba server.

**What it does:**
- Asks for SMB server IP address
- Lists all accessible shares
- Displays permissions (read/write)
- Detects anonymous shares
- Logs results in `/opt/balorsh/data/remoteaccess/smb/`

**Tools used:** `smbclient`, `enum4linux`

**Use cases:** 
- Network share enumeration
- Security audit (misconfigured shares)
- Accessible resource discovery

**Example:**
```bash
SMB Server: 192.168.1.50

Shares found:
- \\192.168.1.50\Public (READ/WRITE)
- \\192.168.1.50\Docs (READ)
- \\192.168.1.50\IPC$ (IPC)
```

**Information displayed:**
- Share name
- Type (Disk, IPC, Printer)
- Permissions
- Descriptive comment

---

### [8] List NFS Exports (showmount)

Lists available NFS exports on a remote server.

**What it does:**
- Asks for NFS server IP address
- Queries server to list exports
- Displays exported paths and restrictions
- Logs results in `/opt/balorsh/data/remoteaccess/nfs/`

**Tools used:** `showmount`

**Use cases:** 
- NFS export discovery
- NFS configuration audit
- Mount planning

**Example:**
```bash
NFS Server: 192.168.1.75

Available exports:
/export/data     192.168.1.0/24
/export/backups  192.168.1.10
/export/public   * (everyone)
```

**Information displayed:**
- Export path
- Access restrictions (IP/network)
- Export options

---

### [9] Clean Old Sessions

Removes old session log files to free disk space.

**What it does:**
- Asks for age threshold (in days)
- Searches for log files older than the threshold
- Displays list of files to delete
- Asks for confirmation before deletion
- Deletes validated files

**Use cases:** 
- Regular log maintenance
- Disk space liberation
- Compliance with data retention policies

**Example:**
```bash
Delete logs older than how many days? 30

Files to delete:
/opt/balorsh/data/remoteaccess/ssh/20231015_143022_192.168.1.100.log
/opt/balorsh/data/remoteaccess/rdp/20231018_091533_192.168.1.200.log
Total: 2 files (15 MB)

Confirm deletion? (y/n): y
✓ Files deleted
```

---

### [10] Help

Displays complete help for the Remote Access stack.

**What it does:**
- Lists all available features
- Explains use cases for each tool
- Displays prerequisites and dependencies
- Provides usage examples

**Help contents:**
- Description of supported protocols
- Session log locations
- Security tips
- Common troubleshooting

---

## Configuration and Prerequisites

### Required packages

The Remote Access stack requires the following packages:

**SSH:**
- `openssh-client`
- `sshpass`

**RDP:**
- `freerdp` (or `rdesktop`)
- `remmina` (optional, for GUI)

**SMB/Samba:**
- `smbclient`
- `cifs-utils`
- `enum4linux` (optional)

**NFS:**
- `nfs-common` (Debian/Ubuntu)
- `nfs-utils` (RHEL/CentOS/Arch)

**Scan:**
- `nmap`

### Automatic installation

Packages are automatically installed via:
```bash
cd /home/idenroad/GIT/Balor
./balorsh -i remoteaccess
```

Or manually via the installation script:
```bash
cd stacks/remoteaccess
sudo ./install.sh
```

---

## Security

### Best practices

1. **Passwords**: Passwords are requested in shadow mode (not visible on screen)
2. **Logs**: All sessions are logged for audit purposes
3. **Permissions**: Log files are created with restrictive permissions
4. **Cleanup**: Regularly delete old logs

### Warnings

⚠️ **Password authentication**: Prefer SSH keys/certificates in production

⚠️ **Unencrypted RDP**: Use a VPN/SSH tunnel to secure RDP

⚠️ **SMB shares**: Always verify permissions of mounted shares

⚠️ **Persistent mounts**: Unmount shares after use to avoid data leaks

---

## Troubleshooting

### SSH

**Problem:** Connection refused
```bash
Solution: Check that SSH service is active on remote server
sudo systemctl status sshd
```

**Problem:** Permission denied
```bash
Solution: Verify credentials and permissions
cat /var/log/auth.log  # on server
```

### RDP

**Problem:** xfreerdp won't connect
```bash
Solution: Try rdesktop or check Windows RDP service
netstat -an | grep 3389  # on Windows server
```

**Problem:** Invalid certificate
```bash
Solution: The /cert-ignore option is already used automatically
```

### SMB

**Problem:** Mount fails
```bash
Solution: Verify cifs-utils is installed and user has sudo rights
sudo apt install cifs-utils
```

**Problem:** Access denied to share
```bash
Solution: Verify credentials and SMB permissions
smbclient -L //server -U username
```

### NFS

**Problem:** Mount permission denied
```bash
Solution: Check /etc/exports on NFS server
showmount -e nfs_server
```

**Problem:** NFS version mismatch
```bash
Solution: Try NFSv3 if NFSv4 fails
mount -t nfs -o vers=3 server:/export /mnt/point
```

---

## Usage Examples

### Typical workflow - Server administration

1. Scan network to find services:
   ```
   Menu [6] → Scan services → 192.168.1.0/24
   ```

2. Connect via SSH to detected server:
   ```
   Menu [1] → SSH → 192.168.1.100 → admin
   ```

3. Review session logs:
   ```
   cat /opt/balorsh/data/remoteaccess/ssh/20240115_143500_192.168.1.100.log
   ```

### Typical workflow - Network share access

1. List available SMB shares:
   ```
   Menu [7] → List shares → 192.168.1.50
   ```

2. Connect to chosen share:
   ```
   Menu [4] → Samba connection → 192.168.1.50 → Public
   ```

3. Choose GUI method for ease of use

### Typical workflow - NFS storage

1. List NFS exports:
   ```
   Menu [8] → List exports → 192.168.1.75
   ```

2. Mount desired export:
   ```
   Menu [5] → NFS mount → /export/data → /mnt/nas
   ```

3. Use share as local folder

4. Unmount after use:
   ```bash
   sudo umount /mnt/nas
   ```

---

## File Structure

```
/opt/balorsh/data/remoteaccess/
├── ssh/
│   ├── 20240115_143500_192.168.1.100.log
│   └── 20240115_150230_server1.log
├── rdp/
│   ├── 20240115_144200_192.168.1.200.log
│   └── 20240115_151045_winserver.log
├── smb/
│   ├── 20240115_145100_192.168.1.50_shares.log
│   └── 20240115_152300_192.168.1.50_Public.log
└── nfs/
    ├── 20240115_150000_192.168.1.75_exports.log
    └── 20240115_153030_192.168.1.75_mount.log
```

---

## Return to Menu

After each operation (connection, scan, enumeration), you automatically return to the main menu to chain actions.

To exit the Remote Access stack: select `[0] Return` or press `Ctrl+C`.

---

**Version:** 1.0  
**Last updated:** January 2024
