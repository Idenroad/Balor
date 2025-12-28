## BalorSH — Framework (Practical Overview)

This document explains the `framework` stack in practical terms for users and contributors: menu behavior, data locations, workflows, and how to extend the stack.

Key locations

- Stack data: `/opt/balorsh/data/framework/`
- Helpful env vars: `FRAMEWORK_LHOST`, `FRAMEWORK_LPORT`, `FRAMEWORK_TARGET`

Menu overview

The `framework` menu is organized into sections: Burp Suite, Metasploit, ExploitDB, Workflows, CVE and Help. Each numeric option maps to a `framework_<action>()` function implemented in `stacks/framework/commands.sh`.

Burp Suite

- **1) Launch Burp Suite** — starts Burp in background (non-systemd) and confirms launch.
- **2) Proxy setup** — toggles `http_proxy`/`https_proxy` to `127.0.0.1:8080` for redirecting local traffic through Burp.
- **3) Export Burp CA** — exports `burp_ca_cert.der` into the framework data directory for browser import.

Metasploit

- **4) Open `msfconsole`** — interactive metasploit console.
- **5) Initialize msf database** — runs `msfdb init --use-defaults` with a timeout to avoid hangs.
- **6) Update Metasploit** — runs `paru -S metasploit-git` with timeout.
- **7) Start handler** — asks LHOST/LPORT and payload, then launches a handler via `msfconsole` (with timeout).
- **8) Generate reverse payload** — creates payloads (exe/elf/php/python/apk) using `msfvenom` and prints handler commands.
- **9) Run Metasploit scanners** — select scanner modules (http/ssh/ftp/smb/mysql/arp) and log output.
- **10) Advanced payload generation** — add encoders (shikata, xor) and advanced options.

ExploitDB

- **11) Update ExploitDB** — synchronize a local database of exploits.
- **12) ExploitDB search** — search local ExploitDB by keyword/CVE.
- **13) Copy exploit** — export an exploit to a workspace.
- **14) Advanced search** — advanced filters and examples.
- **15) Compile C exploit** — local compilation using `gcc` when applicable.

Workflows & Utilities

- **16) Payload + Handler workflow** — automate generating a payload and launching a handler.
- **17) Scan → Exploit workflow** — run a scan and propose matching exploits.
- **18) Show IP** — print local/public IP useful for handlers.

CVE & Help

- **19) CVE search (balorcve)** — launches `balorcve` if available; otherwise prints install instructions (pipx).
- **20) Detailed help** — show help text and usage examples.

Common behaviors

- Commands are printed before execution and require confirmation for destructive actions.
- Logs are saved as `.log` and cleaned into `.txt` (non-printable characters removed). All logs live under `$FRAMEWORK_DATA_DIR`.
- Long or blocking operations are wrapped with `timeout` to avoid hanging the interface.

Example structure

```
/opt/balorsh/data/framework/
├── metasploit/
│   └── scan_*.log
├── burpsuite/
│   └── burp_ca_cert.der
└── balorcve/
	└── balorcve_YYYYMMDD_HHMMSS.log
```

Contributor guidance

1. Add clear `framework_<action>()` functions for new actions.
2. Add the action to the `case` in `stack_menu()` in `stacks/framework/commands.sh`.
3. Use helpers in `lib/common.sh` (`run_direct`, `run_bg_stream`, i18n helpers) for consistent behavior.
4. Make scripts idempotent and test with `NO_MAIN_MENU=1` for non-interactive runs.

Debugging

To test a function in isolation:

```bash
NO_MAIN_MENU=1 bash -c 'source stacks/framework/commands.sh; framework_msf_payload_reverse'
```

Check logs under `/opt/balorsh/data/framework/` and job files in `$JOB_DIR` for background tasks.

i18n

- Menu texts use keys defined in `lib/lang/fr.sh` and `lib/lang/en.sh`. Add keys when introducing new prompts.

Security & ethics

- Do not run offensive workflows on unauthorized targets.
- Protect generated payloads and logs; sanitize before sharing.

See also: `stacks/framework/commands.sh` and `lib/common.sh`.

