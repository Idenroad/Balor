## BalorSH — OSINT (Overview)

This page documents the Balor **OSINT** stack: purpose, included tools, installation and common usage.

### Purpose

The `osint` stack provides tools and scripts for open-source intelligence collection: subdomain enumeration, public data collection, web reconnaissance and attack surface analysis.

### Notable tools

- `theHarvester` — collects emails, subdomains and public information
- `censys` (installed via `pipx`) — query Censys data
- Various utilities: `nmap`, `masscan`, `amass` (AUR), `waybackurls`, `gau` (AUR)

### Installation

Install the stack:

```bash
cd /path/to/Balor
sudo bash stacks/osint/install.sh
```

The script installs pacman/AUR packages and, if `pipx` is present, installs `censys` and `theHarvester` via `pipx`.

### Configuration and usage

- Data and installation markers are stored under `/opt/balorsh/data/osint/`.
- `pipx`-installed tools are managed globally; call the provided commands (`censys`, `theHarvester`) from scripts.

### Best practices

- Check API keys and quotas (e.g., Censys) before use.
- Respect laws and ethical guidelines when performing data collection.
