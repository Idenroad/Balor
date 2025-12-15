# Recommended WiFi Chipsets for Pentesting

This document lists WiFi chipsets compatible with pentesting tools on Linux.

## Compatibility Table

| Chipset / Model | Linux Support (monitor mode + injection) | Notes / Remarks |
|------------------|------------------------------------------|-----------------|
| **Atheros AR9271** | ⭐ Excellent | Very stable, native support, used in TP-Link TL-WN722N v1 (⚠️ v2/v3 not compatible) |
| **Ralink RT3070 / RT3572** | ✅ Good | Supported, stable, used in several USB adapters |
| **Realtek RTL8812AU** | ✅ Good with patched drivers | Supports 802.11ac, requires third-party drivers (e.g. aircrack-ng/rtl8812au) |
| **Realtek RTL8814AU** | ✅ Good with patched drivers | 4x4 MIMO support, powerful but more power-hungry |
| **Realtek RTL8822BU** | ⚠️ Variable | Modern chipset with rtw88 driver, partial monitor support, limited injection |
| **Realtek RTL8821** | ⚠️ Variable | Partial support with rtw88 drivers, better with patched drivers |
| **Realtek RTL8187** | ⭐ Excellent | Old but very reliable for injection and monitor |
| **Mediatek MT7610U / MT7612U** | ⚠️ Variable | Partial support, sometimes unstable, needs testing |
| **Broadcom BCM43xx** | ❌ Poor | Generally not recommended for pentesting (no reliable injection support) |
| **Intel Wireless (e.g. 7260, 8265)** | ❌ Poor | Not suitable for pentesting (no monitor/injection mode) |

## Legend

- ⭐ **Excellent**: Complete native support, very stable
- ✅ **Good**: Works well with appropriate drivers
- ⚠️ **Variable**: Partial or unstable support
- ❌ **Poor**: Not recommended, limited or no support

## Important Notes

1. **TP-Link TL-WN722N**: Only version 1 uses the AR9271 chipset. Versions 2 and 3 use Realtek RTL8188EUS which is not suitable for pentesting.

2. **Realtek Drivers**: Realtek chipsets generally require third-party drivers from GitHub (e.g. aircrack-ng/rtl8812au).

3. **Chipset Verification**: Use `lsusb` or `lspci` to identify your chipset before purchasing a WiFi adapter.

## Recommended Adapters

- **TP-Link TL-WN722N v1** (AR9271)
- **Alfa AWUS036NHA** (AR9271)
- **Alfa AWUS036ACH** (RTL8812AU)
- **Alfa AWUS1900** (RTL8814AU)
- **Panda PAU05** (RT3070)
