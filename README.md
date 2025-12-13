# Balor – Idenroad Legion

[Version française](README_fr.md)

<img width="1920" height="461" alt="Idenroad_logo_horizontal_black" src="https://github.com/user-attachments/assets/9ddbef27-f290-4aa9-942b-ee8e7dbdd298" /> <br><br>

**Balor** is a pentesting overlay built on top of [CachyOS Handheld Edition](https://cachyos.org/), designed for portable machines (Steam‑Deck‑like devices, Lenovo Legion Go, laptops, mini‑PCs).  
We used to rely on [BlackArch](https://github.com/BlackArch/blackarch) but compatibility issues forced us to patch many packages.  
We decided to optimize the installation of a smaller, opinionated set of tools we actually use, by forking some BlackArch files and using AUR or CachyOS repositories directly.

**Idenroad** adds a **legion** of pentest and OSINT tools, organized into **stacks** that can be cleanly enabled or removed.

Goal: turn a clean CachyOS base into a **portable offensive platform**, scripted, reproducible, without trashing the whole system.

---

## 🎯 Concept: Overlay on top of CachyOS Handheld Edition

Balor does **not** replace CachyOS:

- You start from a standard **CachyOS Handheld Edition** install.
- The Idenroad overlay adds:
  - per‑stack install / uninstall scripts,
  - minimal integration to avoid polluting the system,
  - an offensive focus (WiFi, OSINT, BLE, remote, etc.).

You keep:

- the optimized kernel, performance and tooling from CachyOS,
- and you add an **offensive “Legion” layer**.

---
## 🌍 Multilingual Support (0.6)

Balor now includes a complete **internationalization (i18n) system** supporting:

- 🇫🇷 **French** (Français)
- 🇬🇧 **English**

The language is **automatically detected** from your system's `LANG` environment variable on CachyOS.

**Quick start:**
```bash
# Use with auto-detection (default)
./balorsh

# Force a specific language
BALOR_LANG=fr ./balorsh   # French
BALOR_LANG=en ./balorsh   # English
```

📚 **Full documentation:**

---
## 🛡️ “Legion” Concept

The **Legion** idea: a curated set of tools, tested and integrated, rather than a huge bag of random packages.

- Each *legion* = a thematic **stack** (WiFi, OSINT, Password, Remote, etc.).
- Each stack:
  - has its own `install.sh` / `uninstall.sh`,
  - uses a `packages.txt` file to declare dependencies (`pacman:` / `aur:`),
  - avoids side‑effects (NetworkManager, Java, system services, etc.),
  - can be added or removed without breaking the rest.

<br>
<img width="862" height="457" alt="Copie d&#39;écran_20251212_093355" src="https://github.com/user-attachments/assets/0dd9f2de-e5a9-4e3c-80f1-f601778d6d7f" />



---

## 📦 Available stacks

Current Balor stacks.

> Numbers in parentheses are internal stack versions used only for tracking (0.x).

## ⚙️ balorsh — The wrapper (core feature) (0.6)

`balorsh` is the central command wrapper for this project — essentially the
feature that brings the overlay to life. It loads the framework installed in
/opt/balorsh and exposes per-stack menus, helper commands and a consistent
CLI surface so you don't have to call individual scripts directly.

Usage examples:

- Open the WiFi stack menu: `balorsh wifi` (stack example: `balorsh wifi (0.6)`)
- List available stacks: `balorsh list`

Using `balorsh` is the recommended way to interact with stacks — it provides
validation, consistent UX and easier upgrades compared to running stack
installers or scripts manually.

Note: These stacks and the `balorsh` wrapper are primarily targeted at
CachyOS / CachyOS Handheld Edition (the project is designed to integrate
cleanly with that base system).

Tip: In the WiFi stack menu you can use option [22] for Help and option [23] to restart NetworkManager.

Inspiration and improvements: the design borrows ideas from [NETREAPER](https://github.com/Nerds489/NETREAPER/). However, Balor extends that model with extra utilities for cracking workflows — interactive wordlist selection, recursive concatenation of multiple lists into a prepared temporary wordlist, and direct integration with `aircrack-ng`/`hashcat` for a smoother cracking experience.

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

- `roguehostapd`: rogue AP / evil twin.
- `wifiphisher`: captive portal, WiFi phishing.

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

## 🎯 Global objectives

- **compatibility**: tools patched for CachyOS Handheld Edition.
- **user‑friendly**: per‑stack install/uninstall, no need to be an Arch/AUR guru.
- **reproducibility**: same machine + same script ⇒ same result.

---

## ⚡ Quick Install

```bash
git clone https://github.com/Idenroad/Balor.git
cd Balor
chmod +x install.sh
./install.sh
```

In the menu, press **5** to install balorsh and all stacks in `/opt/balorsh`

In your terminal, you can use:

```bash
balorsh --help
balorsh --version
balorsh list
sudo balorsh <stack>
```

**For updating Balor:**

1. Download the new release or `git clone`
2. `cd Balor`
3. `chmod +x install.sh`
4. `./install.sh`
5. Choose **5** again in the menu

**Recommended:** Install ALL stacks!

---

## 🚀 Requirement


- A working **CachyOS Handheld Edition** installation.
- Root / `sudo` access.
- Internet connection (packages + AUR).

One option in the script allows you to **upgrade everything**:

- CachyOS core,
- installed packages,
- Balor tools.

> ⚠️ Warning: this affects the **whole system**, like a full Arch/CachyOS upgrade.  
> Use it only if you know what you’re doing.

---

**Target platforms:** Lenovo Legion Go, Steam Deck and other handhelds / laptops.

![legiongo](https://github.com/user-attachments/assets/4ecfc90d-9e0c-4557-9fc0-34f9de4bd04a)

---

## 🗺️ Roadmap (next legions)

Some ideas for future stacks / legions:

- **BLE / RF**: tools like `btlejack`, basic NRF / RF analysis.
- **Reporting**: report templates, small artifact‑collection scripts.
- **Forensics / light IR**: post‑exploitation analysis tools, log / artifact collection.
- **Doc / Cheatsheets**: offline helper stack for working on the go.

---

## 🛠️ Quickstart: WiFi + OSINT pentest with Idenroad

### Scenario: WiFi audit + OSINT on a target

1. **Start an evil twin with roguehostapd:**

   ```bash
   sudo roguehostapd -i wlan1 -e "FreeWiFi" -c 6
   ```

2. **Run a captive portal with wifiphisher:**

   ```bash
   sudo wifiphisher -aI wlan1 -e "FreeWiFi"
   ```

3. **Run theHarvester on a target domain:**

   ```bash
   theHarvester -d example.com -b all
   ```

4. **Launch Maltego (with a working Java setup):**

   ```bash
   maltego
   ```

---

## ⚠️ Disclaimer / Legal usage

**Balor / Idenroad Legion** is aimed at **CachyOS enthusiasts**, **security practitioners**, and **handheld PC fans**.

- ❌ Only use these tools on systems for which you have **explicit written permission**.
- ❌ Any malicious, unauthorized or illegal use is strictly forbidden.
- ✅ Always comply with local and international cybersecurity laws.

Balor / Idenroad authors and contributors **cannot be held responsible** for any misuse of these tools.

---

## 📧 Contact

- **Idenroad**: https://idenroad.ca  
- **GitHub**: https://github.com/idenroad/Balor
