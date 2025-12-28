# Chipsets WiFi recommandés pour le pentesting (Linux)

Ce document présente les chipsets recommandés, leur niveau de compatibilité (mode monitor + injection) et des conseils d'achat et d'installation.

## Tableau de compatibilité

| Chipset / Modèle | Support Linux (monitor + injection) | Notes |
|------------------|-------------------------------------:|-------|
| **Atheros AR9271** | ⭐ Excellent | Support natif, stable. Présent sur TP‑Link TL‑WN722N v1 (v2/v3 NON compatibles).
| **Ralink RT3070 / RT3572** | ✅ Bon | Large support, utilisé sur de nombreux adaptateurs USB.
| **Realtek RTL8812AU** | ✅ Bon (drivers patchés) | 802.11ac — nécessite drivers tiers (aircrack-ng/rtl8812au, dkms).
| **Realtek RTL8814AU** | ✅ Bon (drivers patchés) | 4×4 MIMO — puissant, demande des drivers spécifiques.
| **Realtek RTL8822BU / RTL8821** | ⚠️ Variable | Support partiel (rtw88 ou drivers tiers). Injection parfois limitée.
| **Realtek RTL8187** | ⭐ Excellent | Ancien mais très fiable pour injection/monitor.
| **Mediatek MT7610U / MT7612U** | ⚠️ Variable | Support instable selon la distribution et le driver.
| **Broadcom BCM43xx** | ❌ Mauvais | Généralement non adapté (injection peu fiable, drivers propriétaires).
| **Intel Wireless (ex: 7260, 8265)** | ❌ Mauvais | Pas de support fiable pour monitor/injection — pas recommandé.

## Légende

- ⭐ Excellent : support natif complet, très stable
- ✅ Bon : fonctionne bien avec drivers appropriés
- ⚠️ Variable : support partiel ou instable, à tester
- ❌ Mauvais : non recommandé pour pentesting

## Conseils avant achat

1. Vérifiez la révision matérielle : la même référence commerciale peut embarquer plusieurs chipsets (ex. TL‑WN722N v1 ≠ v2/v3).
2. Privilégiez les chipsets Atheros/RTL8187 pour la fiabilité si vous débutez.
3. Si vous choisissez Realtek/Mediatek, préparez‑vous à compiler/installer des drivers tiers (DKMS) et testez l'injection.
4. Évitez Broadcom et les cartes Intel pour les usages pentest.

### Commandes utiles pour identifier le chipset

```bash
lsusb
lspci -nnk | grep -iA3 wireless
```

## Drivers et installation

- Realtek : consulter `aircrack-ng/rtl8812au`, `morrownr/8821au` ou `morrownr/rtl88xxau` selon le modèle.
- Mediatek : rechercher `mt7610u`/`mt7612u` sur GitHub et vérifier la compatibilité kernel.
- Utiliser `dkms` quand possible pour garder les drivers après mise à jour du noyau.

## Adaptateurs recommandés

- TP‑Link TL‑WN722N v1 (AR9271)
- Alfa AWUS036NHA (AR9271)
- Alfa AWUS036ACH (RTL8812AU)
- Alfa AWUS1900 (RTL8814AU)
- Panda PAU05 (RT3070)

## Remarques pratiques

- Testez l'injection et le mode monitor dès que possible après achat (sur une machine de test autorisée).
- Préparez une petite distribution live (Kali/Parrot) pour valider le bon fonctionnement avant intégration.

## Remarques légales et éthiques

- N'effectuez des tests que sur des réseaux dont vous avez l'autorisation explicite.
- Respectez la loi et les règles d'utilisation de votre pays.

- **Alfa AWUS1900** (RTL8814AU)
- **Panda PAU05** (RT3070)
- **Alfa AWUS036ACM** (MT7610U)
- **AWUS036ACM** (MT7612U)
