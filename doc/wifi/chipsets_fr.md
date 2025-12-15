# Chipsets WiFi Recommandés pour Pentesting

Ce document liste les chipsets WiFi compatibles avec les outils de pentesting sous Linux.

## Tableau de Compatibilité

| Chipset / Modèle | Support Linux (mode monitor + injection) | Notes / Remarques |
|------------------|------------------------------------------|-------------------|
| **Atheros AR9271** | ⭐ Excellent | Très stable, support natif, utilisé dans TP-Link TL-WN722N v1 (⚠️ v2/v3 non compatibles) |
| **Ralink RT3070 / RT3572** | ✅ Bon | Supporté, stable, utilisé dans plusieurs adaptateurs USB |
| **Realtek RTL8812AU** | ✅ Bon avec drivers patchés | Supporte 802.11ac, nécessite drivers tiers (ex: aircrack-ng/rtl8812au) |
| **Realtek RTL8814AU** | ✅ Bon avec drivers patchés | Support 4x4 MIMO, puissant mais plus gourmand |
| **Realtek RTL8822BU** | ⚠️ Variable | Chipset moderne avec driver rtw88, support monitor partiel, injection limitée |
| **Realtek RTL8821** | ⚠️ Variable | Support partiel avec drivers rtw88, mieux avec drivers patchés |
| **Realtek RTL8187** | ⭐ Excellent | Ancien mais très fiable pour injection et monitor |
| **Mediatek MT7610U / MT7612U** | ⚠️ Variable | Support partiel, parfois instable, à tester |
| **Broadcom BCM43xx** | ❌ Mauvais | Généralement déconseillé pour pentesting (pas de support injection fiable) |
| **Intel Wireless (ex: 7260, 8265)** | ❌ Mauvais | Pas adapté au pentesting (pas de mode monitor/injection) |

## Légende

- ⭐ **Excellent** : Support natif complet, très stable
- ✅ **Bon** : Fonctionne bien avec drivers appropriés
- ⚠️ **Variable** : Support partiel ou instable
- ❌ **Mauvais** : Non recommandé, support limité ou inexistant

## Notes Importantes

1. **TP-Link TL-WN722N** : Seule la version 1 utilise le chipset AR9271. Les versions 2 et 3 utilisent Realtek RTL8188EUS qui n'est pas adapté au pentesting.

2. **Drivers Realtek** : Les chipsets Realtek nécessitent généralement l'installation de drivers tiers depuis GitHub (ex: aircrack-ng/rtl8812au).

3. **Vérification du chipset** : Utilisez `lsusb` ou `lspci` pour identifier votre chipset avant l'achat d'un adaptateur WiFi.

## Adaptateurs Recommandés

- **TP-Link TL-WN722N v1** (AR9271)
- **Alfa AWUS036NHA** (AR9271)
- **Alfa AWUS036ACH** (RTL8812AU)
- **Alfa AWUS1900** (RTL8814AU)
- **Panda PAU05** (RT3070)
