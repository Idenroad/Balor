# balorsh password - Password Cracking Stack Commands Reference

[Version française](balorsh_password_fr.md)

This document describes all menu options available in the Password Cracking stack of balorsh.

## Table of Contents

- [Hash Identification](#hash-identification)
- [Hashcat (GPU)](#hashcat-gpu)
- [John the Ripper (CPU)](#john-the-ripper-cpu)
- [Wordlist Generation](#wordlist-generation)
- [Network Attacks](#network-attacks)
- [Utilities](#utilities)

---

## Hash Identification

### [1] Identify hash type (hashid)

Identifies the type of hash to help you choose the right cracking mode.

**What it does:**
- Asks if you want to identify a single hash or a file of hashes
- Uses `hashid` to analyze and identify hash types
- Shows all possible hash types with hashcat and john modes
- Saves results to `/opt/balorsh/data/password/hashid/identify_*.txt`

**Use case:** Before cracking, identify what type of hash you have (MD5, SHA1, bcrypt, etc.).

**Output example:**
```
Analyzing hash: 5f4dcc3b5aa765d61d8327deb882cf99
Possible Hashs:
[+] MD5
[+] Domain Cached Credentials - MD4(MD4(($pass)).(strtolower($username)))
```

---

### [2] List available wordlists

Interactive browser to explore wordlists available on the system.

**What it does:**
- Shows wordlists organized by directory in `/usr/share/wordlists`
- Displays file sizes and line counts
- Allows navigation through subdirectories
- Shows statistics for each directory

**Use case:** Explore available wordlists before launching an attack.

**Features:**
- Browse directories interactively
- View file sizes and line counts
- Return to parent directory or root
- Quickly find the right wordlist for your attack

---

## Hashcat (GPU)

### [3] Hashcat: Dictionary attack

GPU-accelerated hash cracking using a wordlist.

**What it does:**
- Asks for a hash file to crack
- Asks for hashcat mode (0=MD5, 1000=NTLM, 22000=WPA, etc.)
- Lets you select a wordlist (rockyou.txt, browse, or custom)
- Launches hashcat in dictionary mode
- Saves session to `/opt/balorsh/data/password/hashcat/session_*.txt`

**Use case:** Fast hash cracking using GPU power and a wordlist.

**Common modes:**
- `0` - MD5
- `100` - SHA1
- `1000` - NTLM
- `1400` - SHA256
- `1800` - sha512crypt (Linux)
- `3200` - bcrypt
- `5600` - NetNTLMv2
- `22000` - WPA/WPA2 (PMKID/EAPOL)

**Tip:** For full mode list, run `hashcat --help | grep 'Hash modes'`

---

### [4] Hashcat: Rules-based attack

Dictionary attack enhanced with transformation rules.

**What it does:**
- Asks for hash file and mode
- Asks for wordlist
- Asks for rules file (best64.rule, rockyou-30000.rule, dive.rule, or custom)
- Applies transformations to wordlist entries (leetspeak, case changes, etc.)
- Significantly increases cracking success rate

**Use case:** When dictionary attack fails, rules apply variations to each word.

**Popular rules:**
- `best64.rule` - Optimal balance of speed and efficiency
- `rockyou-30000.rule` - More comprehensive rules
- `dive.rule` - Deep rule set

**Example:** Password "password" becomes: Password, p@ssword, PASSWORD, passw0rd, etc.

---

### [5] Hashcat: Bruteforce (mask attack)

Systematic bruteforce using character masks.

**What it does:**
- Asks for hash file and mode
- Asks for a mask pattern
- Tests all possible combinations matching the mask
- Can be very slow depending on mask complexity

**Use case:** When you know the password structure (e.g., 8 characters with specific patterns).

**Mask syntax:**
- `?l` = lowercase (a-z)
- `?u` = uppercase (A-Z)
- `?d` = digits (0-9)
- `?s` = special characters (!@#$...)
- `?a` = all characters

**Examples:**
- `?l?l?l?l?l?l` = 6 lowercase letters
- `?u?l?l?l?l?d?d` = Uppercase + 4 lowercase + 2 digits
- `?a?a?a?a?a?a?a?a` = 8 any characters (very slow!)

**Warning:** Bruteforce can take extremely long. Use only when structure is known.

---

### [6] Hashcat: Show results

Display cracked passwords from previous hashcat sessions.

**What it does:**
- Asks for hash file and mode
- Runs `hashcat --show` to display all cracked passwords
- Shows hash:password pairs

**Use case:** View results after a cracking session completes.

---

## John the Ripper (CPU)

### [7] John: Auto/wordlist/incremental crack

Main John the Ripper cracking modes.

**What it does:**
- Offers 3 attack modes:
  1. **Automatic (single)** - Uses username to generate variations
  2. **Wordlist** - Dictionary attack with selected wordlist
  3. **Incremental** - Bruteforce attack
- Saves session to `/opt/balorsh/data/password/john/session_*.txt`

**Use case:** CPU-based cracking when no GPU is available, or for formats John handles better.

**Advantages of John:**
- Very versatile format support
- Excellent automatic mode
- Good for complex hash types

---

### [8] John: Rules-based crack

Dictionary attack with rules transformations.

**What it does:**
- Asks for hash file
- Asks for wordlist
- Asks for rules (best64, d3ad0ne, dive, jumbo)
- Applies transformations to wordlist entries

**Use case:** Increase success rate with password variations.

---

### [9] John: Show results

Display cracked passwords from John sessions.

**What it does:**
- Asks for hash file
- Runs `john --show` to display cracked passwords

**Use case:** View all passwords cracked by John.

---

## Wordlist Generation

### [10] Crunch: Generate custom wordlist

Create custom wordlists based on specific patterns.

**What it does:**
- Asks for minimum and maximum password length
- Asks for character set:
  - Lowercase (a-z)
  - Uppercase (A-Z)
  - Digits (0-9)
  - Lowercase + digits
  - Alphanumeric (a-zA-Z0-9)
  - Custom characters
- Estimates output size
- Generates wordlist to `/opt/balorsh/data/password/crunch/wordlist_*.txt`

**Use case:** Generate targeted wordlists when you know password constraints.

**Warning:** Files can become VERY large quickly!

**Example:** 
- Length 6-8, digits only: ~111 million combinations
- Length 8, alphanumeric: ~218 trillion combinations (not feasible)

---

## Network Attacks

### [11] Medusa: Network attack

Parallel network service brute force.

**What it does:**
- Asks for target (IP or hostname)
- Asks for service (ssh, ftp, http, mysql, postgres, rdp, smb, telnet, vnc, etc.)
- Asks for username or user file
- Asks for wordlist
- Performs parallel login attempts
- Saves results to `/opt/balorsh/data/password/medusa/attack_*.txt`

**Use case:** Test login credentials on network services.

**Supported services:**
- SSH, FTP, HTTP, MySQL, PostgreSQL, RDP, SMB, Telnet, VNC, and more

**Warning:** 
- May lock accounts after failed attempts
- Only use on authorized systems
- Illegal without proper authorization

---

### [12] Ncrack: Network service audit

Network authentication cracker with smart timing.

**What it does:**
- Asks for target (e.g., `ssh://192.168.1.1` or `rdp://192.168.1.10`)
- Offers two modes:
  1. Username + password wordlist
  2. Credentials file (login:password format)
- Performs intelligent timing to avoid detection
- Saves results to `/opt/balorsh/data/password/ncrack/attack_*.txt`

**Use case:** Audit network service authentication security.

**Advantages:**
- Smarter timing than medusa
- Good for evasion
- Handles multiple protocols

---

## Utilities

### [13] Clean up old files

Delete old cracking session files.

**What it does:**
- Asks for file retention age in days (default: 30)
- Searches for old files in:
  - `/opt/balorsh/data/password/hashid/`
  - `/opt/balorsh/data/password/hashcat/`
  - `/opt/balorsh/data/password/john/`
  - `/opt/balorsh/data/password/crunch/`
  - `/opt/balorsh/data/password/medusa/`
  - `/opt/balorsh/data/password/ncrack/`
- Shows files to be deleted
- Asks for confirmation before deleting

**Use case:** Free up disk space from old session files.

---

### [14] Help

Display quick reference help for the password stack.

**What it does:**
- Shows available tools summary
- Displays typical workflow
- Lists common hash types
- Provides performance tips
- Shows usage examples
- Displays legal warnings

**Use case:** Quick reference guide for password cracking.

---

## Typical Workflow

1. **Identify the hash**
   - Use option [1] to identify hash type
   - Note the hashcat or john mode number

2. **Choose your tool**
   - Hashcat (GPU) - Fastest for supported formats
   - John (CPU) - Better for complex formats

3. **Select attack method**
   - Start with dictionary (rockyou.txt)
   - Add rules if dictionary fails
   - Bruteforce as last resort

4. **View results**
   - Use "Show results" option
   - Check saved session files

## Important Notes

**Performance:**
- Hashcat + GPU >> John (CPU) for speed
- MD5: ~10 billion hash/sec (modern GPU)
- bcrypt: ~100k hash/sec (designed to be slow)

**Wordlists:**
- Location: `/usr/share/wordlists/`
- Main: `rockyou.txt` (14M passwords, covers ~80% of cases)
- Collection: SecLists (comprehensive password lists)

**Legal Warning:**
Password cracking should only be performed:
- On your own systems
- In a legal context (authorized penetration test)
- For recovering your own data

Unauthorized access is illegal. Use responsibly.
