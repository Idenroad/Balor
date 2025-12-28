# Balor – Idenroad Legion

[Version française](README_fr.md)

<img width="1920" height="461" alt="Idenroad_logo_horizontal_black" src="https://github.com/user-attachments/assets/9ddbef27-f290-4aa9-942b-ee8e7dbdd298" />

**Balor** is a **modular pentesting framework** built on top of [CachyOS/CachyOS Handheld Edition](https://cachyos.org/), designed to turn CachyOS into a portable offensive toolkit (Steam Deck‑like, Lenovo Legion Go, laptops, mini‑PC) in under 10 minutes.

## 🚀 A Framework, Not Just Scripts

Balor evolved from simple scripts into a full pentesting framework with:

- 🎯 **Modular Architecture** – independent stacks (WiFi, LLM, NetworkScan, Password, OSINT, WebExploit, RemoteAccess)
- 🔧 **Plugin-like stacks** – each stack installs/uninstalls cleanly without polluting the system
- 🌐 **Full i18n** – ~400 strings available in French and English
- 🎨 **Unified UI** – consistent color scheme and standardized menus across stacks
- 📚 **Shared Libraries** – reusable components (`lib/common.sh`, `lib/i18n.sh`)
- 🤖 **AI Integration** – LLM capabilities with security‑oriented personas
- ⚙️ **Centralized Management** – single `balorsh` wrapper for all operations

## 🤖 AI-assisted Security Analysis

The `llm` stack (via Ollama) brings local AI models to Balor for security tasks.

### Security Personas
- 🔴 **Red Team** – offensive security expert
- 🔵 **Blue Team** – defensive security specialist
- 🟣 **Purple Team** – hybrid offensive/defensive recommendations
- 📊 **Log Analyst** – automated log analysis and threat detection
- 🎓 **Base** – general cybersecurity knowledge

### Key features
- 💬 **Interactive Chat** – real-time AI consultations
- 📝 **Log Analysis** – automatic parsing and threat identification
- 💾 **Session Management** – save and review chats and analyses
- 🔄 **Model Switching** – change active models without restarts
- 🧠 **Custom Models** – import and use custom GGUF models

All LLM interactions run locally via Ollama for privacy and offline use.

Goal: turn a clean CachyOS base into a portable offensive platform with AI assistance, reproducible and safe for controlled use.

![legiongo](https://github.com/user-attachments/assets/4ecfc90d-9e0c-4557-9fc0-34f9de4bd04a)

---

## 🎯 Concept: Layer on top of CachyOS Handheld Edition

Balor does not replace CachyOS. It layers on top of a standard CachyOS Handheld Edition install, adding per‑stack install/uninstall scripts, minimal system integration to avoid breaking packages or services, and an offensive orientation (WiFi, OSINT, BLE, remote, etc.).

You keep the optimized kernel and tooling of CachyOS and add a "Legion" layer oriented toward red team usage.

---

## 🌍 Multilanguage support (0.6)

Balor includes an internationalization system supporting French and English. Language is detected from the `LANG` environment variable; override with `BALOR_LANG`.

```bash
# automatic detection
./balorsh

# force language
BALOR_LANG=fr ./balorsh
BALOR_LANG=en ./balorsh
```

---

## 🛡️ Legion concept

Each "legion" is a thematic stack with its own `install.sh`, `uninstall.sh`, `commands.sh`, and `packages.txt` declaring `pacman:` / `aur:` dependencies. Stacks aim to avoid side‑effects and be installable/uninstallable independently.

---

## 📦 Available stacks (summary)

Quick reference of stacks included in the project (versions shown are internal stack versions):

1. 📡 **WiFi** – dedicated WiFi toolkit: aircrack-ng, hcxdumptool, wifiphisher, etc.
2. 🔍 **OSINT** – Maltego, SpiderFoot, theHarvester, censys, amass
3. 🌊 **Framework** – Burp Suite, Metasploit, ExploitDB, balorcve
4. 🐒 **Web Exploit** – gobuster, sqlmap, ffuf, wpscan
5. 🌎 **Network Scanner** – nmap, masscan, arp-scan, tcpdump
6. 💀 **Password** – hashcat, john, hcxkeys, wordlists
7. 👀 **Remote** – remmina, rdesktop, ssh utilities
8. 🤖 **LLM** – Ollama for local AI models

---

### 1. 📡 WiFi Stack

**Included tools:**

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

- Designed to work with a **dedicated WiFi card** (not the main system interface).
- Tries to avoid conflicts with NetworkManager / system services as much as possible.
- Targeted patches for broken imports / scripts (e.g. `hostapdconfig.py`).

**Use cases:**

- `roguehostapd`: rogue AP / evil twin (modified fork upgraded to hostapd 2.11 with WPA3 support - [Idenroad/roguehostapd](https://github.com/Idenroad/roguehostapd)).
- `wifiphisher`: captive portal, WiFi phishing (modified fork - [Idenroad/Wifiphisher](https://github.com/Idenroad/Wifiphisher)).

---

### 2. 🔍 OSINT Stack

**GUI tools:**

- maltego (0.1)
- spiderfoot (0.1)
- python-censys (0.1)

**CLI tools:**

- theharvester-git (0.1)
- amass-bin (0.1)
- recon-ng (0.1)

**Goal:**

- Avoid typical Java issues like:

  > A command line option has attempted to allow or enable the Security Manager.  
  > Enabling a Security Manager is not supported.

- Provide a ready‑to‑go OSINT base on handheld devices.

---

### 3. 🌊 Framework Stack

**Included tools:**

- burpsuite (0.2)
- metasploit (0.2)

**Goal:**

- Provide a **clean, minimal base** for web pentest and post‑exploitation without turning the system into an unmaintainable mess.

---

### 4. 🐒 Web Exploit Stack

**Included tools:**

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

**Goal:**

- Bring the main discovery / bruteforce / exploitation tools for web apps,
- without fighting broken dependencies or outdated scripts.

---

### 5. 🌎 Network Scanner Stack

**Included tools:**

- nmap (0.3)
- masscan (0.3)
- arp-scan (0.3)
- netdiscover (0.3)
- tcpdump (0.3)

**Goal:**

- Provide a simple, stable **network scanning base**, easy to extend.

---

### 6. 💀 Password Stack

**Included tools:**

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

**Goal:**

- Offer a **basic cracking toolbox** (hashes, WiFi handshakes, wordlists),
- without adding dozens of overlapping tools.

---

### 7. 👀 Remote Stack

**Included tools:**

- openssh (0.5)
- freerdp (0.5)
- rdesktop (0.5)
- smbclient (0.5)
- rpcbind (0.5)
- nfs-utils (0.5)
- remmina (0.5)
- remmina‑plugin‑teamviewer (0.5)

**Goal:**

- Ensure core **remote access tools** are present (SSH, RDP, SMB, NFS),
- with a nice UI (Remmina) suited for handhelds.

---

### 8. 🤖 Balor AI (0.8)

**Included tools:**

- ollama (0.8)
- curl (0.8)
- xmllint (0.8)
- tcpdump (0.8)

**AI Models available:**

- Seneca Cybersecurity LLM (~4 GB) — Recommended
- WhiteRabbitNeo 2.5 Qwen Coder (~4 GB)
- Custom GGUF models (via URL)

**Features:**

- **5 dynamic personas**: base, loganalyst, redteam, blueteam, purpleteam
- **Log analysis**: Automatically converts XML/PCAP files and analyzes them with AI
- **Interactive chat**: Conversation with cybersecurity-focused AI models
- **Multi-model support**: Switch between models or install multiple ones
- **Extensible**: Add custom personas by creating Modelfiles in `lib/models/`

**Use cases:**

- Analyze Balor output logs (XML, PCAP, TXT) with AI assistance
- Get cybersecurity advice from specialized AI personas
- Perform offensive/defensive security research with AI-powered insights
- Generate and analyze security reports

**Goal:**

- Bring **local AI assistance** directly into your pentesting workflow,
- with privacy-focused, offline LLMs running entirely on your device.

---

## 🎯 Global objectives

- **compatibility**: tools patched for CachyOS Handheld Edition.
- **user‑friendly**: per‑stack install/uninstall, no need to be an Arch/AUR guru.
- **reproducibility**: same machine + same script ⇒ same result.

---

## ⚡ Quick install

```bash
git clone https://github.com/Idenroad/Balor.git
cd Balor
chmod +x install.sh
./install.sh
```

In the interactive menu choose the option to install `balorsh` and the stacks into `/opt/balorsh` (option 6 in the installer UI).

Commands:

```bash
balorsh --help
balorsh --version
balorsh list
sudo balorsh <stack>
```

Recommended: install all stacks for a complete environment.

---

## 🚀 Requirements

- CachyOS Handheld Edition installed
- Root / sudo access
- Internet connection for package and AUR downloads

---

## 🗺️ Roadmap

- Document and improve reporting templates
- Forensics / IR tooling
- Expanded documentation and cheat sheets
- Telephony stack (SMS, SIP)
- Enhanced AI orchestration features

---

## ⚠️ Legal / Disclaimer

Balor is intended for security professionals and enthusiasts. Use only on systems for which you have explicit authorization. The authors are not responsible for misuse.

---

## 📧 Contact

- **Idenroad**: https://idenroad.ca  
- **GitHub**: https://github.com/idenroad/Balor

---

## ⚠️ Disclaimer / Legal usage

**Balor / Idenroad Legion** is aimed at **CachyOS enthusiasts**, **security practitioners**, and **handheld PC fans**.

- ❌ Only use these tools on systems for which you have **explicit written permission**.
- ❌ Any malicious, unauthorized or illegal use is strictly forbidden.
- ✅ Always comply with local and international cybersecurity laws.

Balor / Idenroad authors and contributors **cannot be held responsible** for any misuse of these tools.

---


