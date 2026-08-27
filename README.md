# MyLife

Application mobile Android (Flutter) de **suivi de vie au quotidien**, 100 % locale et chiffrée.

## 📲 Télécharger

👉 **[Dernière version (APK)](../../releases/latest)** — télécharge le fichier `MyLife-….apk`, puis autorise l'installation depuis des sources inconnues.

## ✨ Fonctionnalités

- **💰 Finances** : dépenses & catégorisation, import de relevés CSV, poches d'épargne pondérées, récurrents & reste à vivre, prévision de trésorerie, patrimoine net & multi-comptes, analyse par IA.
- **🩺 Santé** : sommeil, douleurs, médicaments avec rappels, export PDF pour le médecin.
- **🥗 Diète** : repas, calories & macros, scan code-barres (OpenFoodFacts), poids, activité, suggestions de menus.
- **📅 Agenda** : rappels avec notifications, synchronisation des agendas Google/Outlook du téléphone.
- **🤖 Assistant Claude** : chat contextualisé sur tes données, actions par la voix, bilan hebdomadaire.
- **🔗 Insights** : corrélations sommeil ↔ douleurs ↔ alimentation ↔ dépenses.
- **🔒 Sécurité** : base SQLCipher chiffrée, verrouillage PIN/biométrie, sauvegarde chiffrée.

## 🔑 Assistant IA

L'assistant utilise l'API Claude d'Anthropic. Colle ta propre clé API dans **Réglages ▸ Clé API** (stockée chiffrée sur l'appareil, jamais partagée).

## 🛠️ Développement

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Stack : Flutter · Riverpod · Drift/SQLCipher · go_router · fl_chart.

---

🤖 Développé avec [Claude Code](https://claude.com/claude-code)
