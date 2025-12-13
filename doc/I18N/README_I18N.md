# Balor Multilingual System

## 🌍 Overview

Balor now supports **2 languages** with automatic detection:
- 🇫🇷 **French** (fr)
- 🇬🇧 **English** (en)

The language is automatically detected from the CachyOS `LANG` environment variable.

## ✨ Features

- ✅ Automatic system language detection
- ✅ Complete French and English support
- ✅ On-the-fly language switching
- ✅ Parameterized messages (with dynamic variables)
- ✅ Modular and extensible architecture
- ✅ Compatible with all Balor scripts

## 🚀 Quick Start

### Normal usage (auto-detection)

```bash
# Language will be automatically detected from $LANG
balorsh

# If LANG=fr_FR.UTF-8 → French interface
# If LANG=en_US.UTF-8 → English interface
```

### Force a specific language

```bash
# Force French
BALOR_LANG=fr balorsh

# Force English
BALOR_LANG=en balorsh
```

### Change system language (CachyOS)

```bash
# Check current language
echo $LANG

# Change temporarily
export LANG=fr_FR.UTF-8  # French
export LANG=en_US.UTF-8  # English

# Change permanently (edit ~/.bashrc or ~/.config/fish/config.fish)
echo 'export LANG=en_US.UTF-8' >> ~/.bashrc
```

## 📂 Structure

```
Balor/
├── lib/
│   ├── i18n.sh          # Main i18n system
│   ├── common.sh        # Common library (loads i18n)
│   └── lang/
│       ├── fr.sh        # 🇫🇷 French translations
│       └── en.sh        # 🇬🇧 English translations
├── stacks/
│   └── wifi/
│       └── commands.sh  # ✅ i18n adapted
├── test_i18n.sh         # Test script
├── extract_i18n.sh      # Extraction helper
├── I18N.md              # Technical documentation
└── MIGRATION_I18N.md    # Migration guide
```

## 🔧 For Developers

### Add a new message

1. **Add in `lib/lang/fr.sh`:**
   ```bash
   MY_MESSAGE="Mon message en français"
   ```

2. **Add in `lib/lang/en.sh`:**
   ```bash
   MY_MESSAGE="My message in English"
   ```

3. **Use in your code:**
   ```bash
   echo "$MY_MESSAGE"
   ```

### Messages with variables

For messages containing dynamic information:

**In fr.sh and en.sh:**
```bash
# French
WIFI_ENABLE_MONITOR="Activation du mode monitor sur %s..."

# English
WIFI_ENABLE_MONITOR="Enabling monitor mode on %s..."
```

**In your code:**
```bash
iface="wlan0"
printf "$WIFI_ENABLE_MONITOR\n" "$iface"
# Displays: "Activation du mode monitor sur wlan0..." (FR)
# Displays: "Enabling monitor mode on wlan0..." (EN)
```

### Test your modifications

```bash
# Run tests
./test_i18n.sh

# Test in French
BALOR_LANG=fr ./stacks/wifi/commands.sh

# Test in English
BALOR_LANG=en ./stacks/wifi/commands.sh
```

## 📚 Complete Documentation

- **[I18N.md](I18N.md)** - Detailed technical documentation
- **[MIGRATION_I18N.md](MIGRATION_I18N.md)** - Migration guide to adapt your scripts
- **[lib/lang/fr.sh](lib/lang/fr.sh)** - All French translations
- **[lib/lang/en.sh](lib/lang/en.sh)** - All English translations

## 🛠️ Included Tools

### test_i18n.sh
Test script to validate the i18n system functionality:
```bash
./test_i18n.sh
```

### extract_i18n.sh
Helper to extract messages from a file and suggest variables:
```bash
./extract_i18n.sh stacks/wifi/install.sh
```

## 🎯 Examples

### Multilingual WiFi Menu

**French (BALOR_LANG=fr):**
```
╔═══════════════════════════════════════════════════════════════════╗
                     📡 WiFi Stack - balorsh                      
╚═══════════════════════════════════════════════════════════════════╝
   ──── Contrôle Interface ────
   [1] Lister interfaces WiFi
   [2] Sélectionner interface WiFi et activer monitor mode
   [3] Désactiver monitor mode sur interface
```

**English (BALOR_LANG=en):**
```
╔═══════════════════════════════════════════════════════════════════╗
                     📡 WiFi Stack - balorsh                      
╚═══════════════════════════════════════════════════════════════════╝
   ──── Interface Control ────
   [1] List WiFi interfaces
   [2] Select WiFi interface and enable monitor mode
   [3] Disable monitor mode on interface
```

### Installation Messages

**French:**
```
[Balor] paru détecté.
  [OK] aircrack-ng déjà installé (pacman).
  [INSTALL] wifite (AUR)...
```

**English:**
```
[Balor] paru detected.
  [OK] aircrack-ng already installed (pacman).
  [INSTALL] wifite (AUR)...
```

## 🌟 Add a New Language

To add a new language (e.g., Spanish):

1. **Create the language file:**
   ```bash
   cp lib/lang/en.sh lib/lang/es.sh
   # Translate all messages to Spanish
   ```

2. **Modify `lib/i18n.sh`:**
   ```bash
   detect_system_language() {
     local sys_lang="${LANG:-en_US.UTF-8}"
     local lang_code="${sys_lang:0:2}"
     
     case "$lang_code" in
       fr) echo "fr" ;;
       en) echo "en" ;;
       es) echo "es" ;;  # ← Add here
       *) echo "en" ;;
     esac
   }
   ```

3. **Test:**
   ```bash
   BALOR_LANG=es ./balorsh
   ```

## 🐛 Troubleshooting

### Language is not detected correctly

```bash
# Check your LANG
echo $LANG

# Force manually
export BALOR_LANG=en
./balorsh
```

### Messages in mixed languages

Check that you don't have hardcoded messages mixed with i18n variables.

### Variables not found

Make sure `lib/common.sh` is loaded before using variables:
```bash
source "$ROOT_DIR/lib/common.sh"
```

## 📊 Current Status

| File | Status | Notes |
|------|--------|-------|
| `lib/i18n.sh` | ✅ Complete | Base i18n system |
| `lib/lang/fr.sh` | ✅ Complete | French translations |
| `lib/lang/en.sh` | ✅ Complete | English translations |
| `lib/common.sh` | ✅ Adapted | Installation messages |
| `stacks/wifi/commands.sh` | ✅ Adapted | WiFi menu and functions |
| Other stacks | ⏳ To do | Can be adapted as needed |

## 🤝 Contributing

To contribute to translations:
1. Check missing messages in `lib/lang/fr.sh` and `lib/lang/en.sh`
2. Add new variables in both files
3. Test with `./test_i18n.sh`
4. Submit your changes

## 📝 License

Same license as the main Balor project.

---

**Developed for CachyOS** 🐧
