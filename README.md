# Balor – Idenroad Legion

[Version française](README_fr.md)

<img width="1920" height="461" alt="Idenroad_logo_horizontal_black" src="https://github.com/user-attachments/assets/9ddbef27-f290-4aa9-942b-ee8e7dbdd298" /> <br><br>

**Balor** is a **modular pentesting framework** built on top of [CachyOS/CachyOS Handheld Edition](https://cachyos.org/), designed to turn CachyOS into a portable offensive toolkit (Steam Deck-like, Lenovo Legion Go, laptops, mini-PC) in under 10 minutes.

## 🚀 A Framework, Not Just Scripts

Balor evolved from simple scripts into a full **pentesting framework** with:

- 🎯 **Modular Architecture** – Independent stacks (WiFi, LLM, NetworkScan, Password, OSINT, WebExploit, RemoteAccess)
- 🔧 **Plugin-like System** – Each stack installs/uninstalls cleanly without polluting the system
- 🌐 **Full i18n** – Over 400 strings translated into French and English
- 🎨 **Unified UI** – Consistent color scheme and standardized menus across all stacks
- 📚 **Shared Libraries** – Reusable components (`lib/common.sh`, `lib/i18n.sh`)
- 🤖 **AI Integration** – LLM capabilities with security-oriented personas
- ⚙️ **Centralized Management** – Single `balorsh` wrapper for all operations

## 🤖 AI-assisted Security Analysis

One of Balor's unique features is the **LLM Stack** powered by Ollama, offering AI-assisted pentesting:

### Security Personas
- 🔴 **Red Team** – Offensive security expert for attack vectors and exploitation
- 🔵 **Blue Team** – Defensive security specialist for hardening and detection
- 🟣 **Purple Team** – Combined offensive/defensive analysis and recommendations
- 📊 **Log Analyst** – Automated log analysis and threat detection
- 🎓 **Base** – General cybersecurity knowledge and education

### Key Features
- 💬 **Interactive Chat** – Real-time consultations with AI security experts
- 📝 **Log Analysis** – Automatic parsing of security logs and threat identification
- 💾 **Session Management** – Save and review conversations and analyses
- 🔄 **Model Switching** – Switch between personas without restarts
- 🧠 **Custom Models** – Import and use your own fine-tuned models

All LLM interactions run **locally** via Ollama for privacy and offline mode.

Goal: transform a clean CachyOS base into a **portable offensive platform** with AI assistance, scripted, reproducible, without breaking the entire system.

---

## 🎯 Concept: Overlay on CachyOS Handheld Edition

Balor **does not replace** CachyOS:

- We start from a standard **CachyOS Handheld Edition** installation.
- The Idenroad overlay adds:
  - Installation/uninstallation scripts per stack,
  - Minimal integration to avoid polluting the system,
  - Offensive orientation (WiFi, OSINT, BLE, remote, etc.).

You keep:

- The optimized kernel, performance, and CachyOS tooling,
- But you add a **"Legion" layer** oriented towards red team.

---
## 🌍 Multilingual Support (0.6)

Balor now includes a **complete internationalization (i18n) system** supporting:

- 🇫🇷 **French**
- 🇬🇧 **English**

The language is **automatically detected** from your system's `LANG` environment variable on CachyOS.

**Quick Start:**
```bash
# Use with automatic detection (default)
./balorsh

# Force a specific language
BALOR_LANG=fr ./balorsh   # French
BALOR_LANG=en ./balorsh   # English
```

📚 **Complete documentation:**

---
## 🛡️ Concept of "Legion"

The idea of the **Legion**: a set of chosen, tested, integrated tools, rather than a big pile of packages installed haphazardly.

- Each *legion* = a **thematic stack** (WiFi, OSINT, Password, Remote, etc.).
- Each stack:
  - Has its own `install.sh` / `uninstall.sh` script,
  - Uses a `packages.txt` file to describe dependencies (`pacman:` / `aur:`),
  - Avoids side effects (NetworkManager, Java, system services, etc.),
  - Can be installed or removed without breaking the rest.

<br>

<img width="590" height="753" alt="Copie d&#39;écran_20251214_185152" src="https://github.com/user-attachments/assets/15592244-d438-4192-9fd7-27452a49ee5b" />


---

## 📦 Available Stacks

For now, Balor includes the following stacks.

> The numbers in parentheses are internal stack versions for tracking (0.x).

## ⚙️ balorsh — The wrapper (central feature) (0.6)

`balorsh` is the main interface of the project — the feature that makes the overlay truly usable. It loads the framework installed in /opt/balorsh and exposes per-stack menus, help commands, and a consistent CLI interface to avoid calling individual scripts.

Usage examples:

- Open the WiFi stack menu: `balorsh wifi` (example stack: `balorsh wifi (0.6)`)
- List available stacks: `balorsh list`

Using `balorsh` is the recommended method for interacting with stacks — it provides validation, consistency, and facilitates updates compared to manual script execution.

Note: These stacks and the `balorsh` wrapper are primarily intended for CachyOS / CachyOS Handheld Edition (the project is designed to integrate properly with this base system).

Tip: In the WiFi stack menu, use option [22] for Help and option [23] to restart NetworkManager.

**Stack Commands**

wifi: 23 choices (0.6)
networkscan: 18 choices (0.7)

Inspiration and improvements: the concept is inspired by [NETREAPER](https://github.com/Nerds489/NETREAPER/). Balor extends this approach by adding cracking utilities — interactive wordlist selection, recursive concatenation of multiple lists into a prepared temporary file, and direct integration with `aircrack-ng`/`hashcat` for a smoother cracking workflow.

### 1. 📡 WiFi Stack

**Included Tools:**

- aircrack-ng (0.1)
- hostapd (0.1)
- roguehostapd (0.3)
- dnsmasq (0.1)
- bettercap (0.1)
- wireshark-qt (0.1)
- git (0.1)
- python (0.1)
- python-pip (0.1)
- scapy (0.1)
- python-tornado (0.1)
- airgeddon (0.1)
- hcxdumptool (0.1)
- hcxtools (0.1)
- python-pyric (0.1)
- wifiphisher (0.1)
- bully (0.4)
- Wifite (0.5.1)

**Characteristics:**

- Designed to work with a **dedicated WiFi card** (not the system's main one).
- Avoids conflicts with NetworkManager / system services as much as possible.
- Targeted patches to fix certain scripts / missing imports (e.g.: `hostapdconfig.py`).

**Usage Examples:**

- `roguehostapd`: creation of rogue AP / evil twin (modified fork updated to hostapd 2.11 with WPA3 support - [Idenroad/roguehostapd](https://github.com/Idenroad/roguehostapd)).
- `wifiphisher`: captive portal, WiFi phishing (modified fork - [Idenroad/Wifiphisher](https://github.com/Idenroad/Wifiphisher)).

---

### 2. 🔍 OSINT Stack

**Included Tools (GUI):**

- maltego (0.1)
- spiderfoot (0.1)
- python-censys (0.1)

**CLI Tools:**

- theHarvester (1.0.0)
- amass-bin (0.1)
- python-shodan (0.9)
- massdns (1.0.0)
- gau (1.0.0)
- waybackurls (1.0.0)
- gittools.git (0.9.5)
- jq (0.1)
- httprobe (1.0.0)
- gitleaks (1.0.0)
- trufflehog (1.0.0)

**Objective:**

- Avoid errors like:

  > A command line option has attempted to allow or enable the Security Manager.  
  > Enabling a Security Manager is not supported.

- Have a ready-to-use OSINT base on handheld.

---

### 3. 🌊 Framework Stack

**Included Tools:**

- burpsuite (0.2)
- metasploit (0.2)
- exploitdb (0.9)
- balor cve-search (1.0.0)

**Objective:**

- Provide a **clean base** for web pentesting and post-exploitation without breaking the entire package system.

---

### 4. 🐒 Web Exploit Stack

**Included Tools:**

- gobuster (0.2)
- sqlmap (0.2)
- hydra (0.2)
- nikto (0.2)
- whatweb-git (0.2)
- getoptlong (0.2)
- resolv-replace (0.2)
- csrf-brute (0.2)
- ffuf (0.2)
- wpscan (0.3)

**Objective:**

- Have the main web discovery / bruteforce / exploitation tools,
- Without fighting with broken dependencies or obsolete scripts.

---

### 5. 🌎 Network Scanner Stack

**Included Tools:**

- nmap (0.3)
- masscan (0.3)
- arp-scan (0.3)
- netdiscover (0.3)
- tcpdump (0.3)
- balor PMF scanner (0.9.5)

**Objective:**

- Create a first simple, stable network base, without trapping the user in a factory of gas.

---

### 6. 💀 Password Stack

**Included Tools:**

- hashcat (0.4)
- hcxkeys (0.4)
- hashcat-utils (0.4)
- handshake-cracker (0.4)
- john the ripper (0.4)
- medusa (0.4)
- ncrack (0.4)
- crunch (0.4)
- hashid (0.4)
- wordlists (0.4)

**Objective:**

- Have a **basic toolbox** for cracking (hashes, WiFi handshakes, wordlists),
- Without stacking 40 redundant tools.

---

### 7. 👀 Remote Stack

**Included Tools:**

- rdesktop (0.5)
- remmina (0.5)
- remmina-plugin-teamviewer (0.5)
- sshpass (0.9)

**Objective:**

- Ensure that the **basic remote access tools** are present (SSH, RDP, SMB, NFS),
- With a practical GUI (Remmina) for handhelds.

### 8. 🤖 LLM Stack

**Included Tools:**

- Ollama (0.6)

**Objective:**

- Easily access local 7B or 13B AIs, via the CLI.

---

## 🔌 Addons System (1.2.0)

Balor now supports **addons** — lightweight extensions that complement the core stacks without being part of the main framework. Addons follow the same modular principles:

- 🧩 **Optional Extensions** – Install only what you need
- 📦 **Self-contained** – Each addon includes its own install/uninstall scripts
- 🎨 **Consistent UI** – Same menus and colors as core stacks
- 🌐 **Full i18n** – French/English support
- 🤖 **balorsh Integration** – Access via `balorsh <addon>` like regular stacks

### 🎯 Available Addons

#### 🎣 Phishing Addon (1.2.0)

**Tools:**
- Gophish (phishing campaign management)
- Zphisher (phishing page templates)
- WifiPumpkin3 (Wi-Fi phishing)

**Use Cases:**
- Campaign management with credential harvesting
- Phishing page generation for awareness tests
- Wi-Fi rogue AP and captive portal attacks

**Quick Start:**
```bash
# Install the addon
./install.sh
# Choose 12) Uninstall an addon → 1) Install addon → select "phishing"

# Use it
balorsh phishing
# Or: sudo balorsh phishing
```

📚 **Complete documentation:** [docs/ADDONS.md](docs/ADDONS.md)  
📖 **Phishing addon guide:** [docs/PHISHING.md](docs/PHISHING.md)

---

## 🎯 Global Objectives

- **compatibility**: tools are patched to be compatible with CachyOS/CachyOS Handheld Edition.
- **user-friendly**: simplified installation and uninstallation, per stack, without needing to know everything about Arch/AUR.
- **reproducibility**: same machine, same script, same result.

---

## ⚡ Quick Installation

```bash
git clone https://github.com/Idenroad/Balor.git
cd Balor
chmod +x install.sh
./install.sh
```

In the menu, press **6** to install balorsh and all stacks in `/opt/balorsh`

In your terminal, you can use:

```bash
balorsh --help
balorsh --version
balorsh list
sudo balorsh <stack>
```

**To update Balor:**

1. Download the new version or `git clone`
2. `cd Balor`
3. `chmod +x install.sh`
4. `./install.sh`
5. Choose **6** again in the menu

**Recommended:** Install ALL stacks!

---

## 🚀 Prerequisites


- A functional **CachyOS Handheld Edition** installation.
- Root / `sudo` access.
- Internet connection (packages + AUR).


One of the script options allows **updating everything**:

- CachyOS core,
- installed packages,
- Balor tools.

> ⚠️ Warning: this option affects the **entire system**. Use it knowingly (like a classic `full-upgrade` under Arch/CachyOS).

---

**Target Platforms:** Lenovo Legion Go, Steam Deck, and other handhelds / laptops.

![legiongo](https://github.com/user-attachments/assets/4ecfc90d-9e0c-4557-9fc0-34f9de4bd04a)

---

## 🗺️ Roadmap (next legions)

Some ideas for future stacks and improvements:

- **Document Management**: help management via glow, document management
- **Reporting**: report templates, artifact collection scripts.
- **Light Forensics / IR**: post-exploitation analysis tools, log collection, interesting binaries.
- **Doc / Cheatsheets**: help management via glow, document management
- **Addon Concept**: Add stacks outside the core 8 for better management
- **Telephony**: Telephony stack, SMS, SIP, etc.
- **AI Orchestration**: Orchestration of scenarios with Balor tools thanks to local LLMs.


---

## ⚠️ Disclaimer / Legal Use

**Balor / Idenroad Legion** is a tool intended for **CachyOS enthusiasts**, **security enthusiasts**, and **PC Handheld fans**.

- ❌ Use these tools **only** on systems for which you have **explicit written authorization**.
- ❌ Any malicious, unauthorized, or illegal use is strictly prohibited.
- ✅ Respect local and international laws regarding cybersecurity.

The authors and contributors of Balor / Idenroad **are not responsible** for the abusive use of these tools.

---

## 📧 Contact

- **Idenroad**: https://idenroad.ca  
- **GitHub**: https://github.com/idenroad/Balor
