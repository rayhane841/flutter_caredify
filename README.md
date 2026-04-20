# CAREDIFY — Application Flutter de Télésurveillance Cardiaque

> **Prototype académique — Mode simulé. Aucune donnée médicale réelle n'est transmise.**

## Aperçu

CAREDIFY est une application mobile de télésurveillance cardiaque pour patients cardiaques, développée en Flutter. Elle simule un système complet de monitoring ECG avec analyse IA et protocole d'urgence médicale validé par cardiologue.

## Fonctionnalités

### 1. Dashboard (Accueil)
- Fréquence cardiaque en temps réel
- Score de risque cardiovasculaire (0-100)
- Prévisualisation ECG animée
- Statut du capteur
- Actions rapides (ECG, Urgence, Carte, Historique)
- Dernières mesures

### 2. ECG en direct
- Tracé ECG 1 dérivation animé avec rendu réaliste (onde P, QRS, onde T)
- Fréquence cardiaque, qualité du signal, intervalles (PR, QRS, QT)
- Analyse IA en temps réel
- Mode nuit (fond noir) en cours de monitoring

### 3. Résultats
- Résumé Normal / Suspect / Critique avec explication en langage simple
- Jauges et métriques détaillées
- Analyse IA (rythme, intervalles, segment ST)
- Recommandations personnalisées
- Statut validation cardiologue

### 4. Urgence (PRIORITÉ)
- **État 1 — Repos** : bouton d'urgence rouge, infos protocole
- **État 2 — Alerte envoyée** : attente validation cardiologue, animation
- **État 3 — Urgence confirmée** : compte à rebours (SAMU arrive dans Xmin), GPS transmis, message de réassurance, bouton appel direct 15

### 5. Carte
- Carte OpenStreetMap via flutter_map (sans clé API)
- Marqueurs : position patient (bleu), DAE (rouge), Hôpitaux (rouge foncé), Cardiologues (bleu)
- Filtres par type de point d'intérêt
- Liste des points les plus proches avec distance

### 6. Historique
- Liste des mesures ECG passées
- Filtres par statut
- Statistiques (normal / suspect / critique)
- Export PDF (interface)

### 7. Profil
- Données patient (nom, âge, groupe sanguin, ID patient)
- Cardiologue référent
- Antécédents médicaux et traitements
- Contact d'urgence

### 8. Paramètres
- Fréquence de monitoring automatique
- Seuil d'alerte IA configurable
- Notifications, GPS, partage données
- Export et gestion données

## Design

- **Couleurs** : Bleu médical (#1565C0) + Blanc — Vert=normal / Orange=suspect / Rouge=critique
- **Typographie** : Inter (400/500/600/700)
- **Radius** : 12-20px
- **Navigation** : Bottom bar avec 5 onglets (bouton urgence central surélevé)

## Structure du projet

```
lib/
├── main.dart                   # Entrée app + navigation principale
├── theme/
│   └── app_theme.dart          # Couleurs, typographie, thème Material 3
├── models/
│   ├── ecg_reading.dart        # Modèle mesure ECG
│   └── patient_profile.dart    # Modèle profil patient
├── providers/
│   └── app_provider.dart       # State management (ChangeNotifier)
├── painters/
│   └── ecg_painter.dart        # Tracé ECG CustomPainter
├── widgets/
│   ├── status_badge.dart       # Badge statut Normal/Suspect/Critique
│   ├── risk_gauge.dart         # Jauge score de risque
│   └── sensor_indicator.dart   # Indicateur capteur connecté
└── screens/
    ├── dashboard_screen.dart
    ├── ecg_screen.dart
    ├── results_screen.dart
    ├── emergency_screen.dart
    ├── map_screen.dart
    ├── history_screen.dart
    ├── profile_screen.dart
    └── settings_screen.dart
```

## Installation et démarrage

### Prérequis
- Flutter SDK ≥ 3.0.0
- Dart ≥ 3.0.0
- Android Studio / VS Code avec extensions Flutter

### Étapes

1. **Cloner / extraire** le projet dans un dossier
2. **Installer les dépendances** :
   ```bash
   flutter pub get
   ```
3. **Lancer sur émulateur ou appareil** :
   ```bash
   flutter run
   ```
4. **Build APK (Android)** :
   ```bash
   flutter build apk --release
   ```
5. **Build iOS** (Mac requis) :
   ```bash
   flutter build ios --release
   ```

## Dépendances principales

| Package | Version | Usage |
|---------|---------|-------|
| `provider` | ^6.1.2 | State management |
| `shared_preferences` | ^2.2.3 | Persistance locale |
| `fl_chart` | ^0.69.0 | Graphiques (optionnel) |
| `flutter_map` | ^7.0.2 | Carte OpenStreetMap |
| `latlong2` | ^0.9.1 | Coordonnées GPS |
| `intl` | ^0.19.0 | Formatage dates (fr_FR) |
| `google_fonts` | ^6.2.1 | Police Inter |
| `percent_indicator` | ^4.2.3 | Indicateurs circulaires |

> **Note sur la carte** : `flutter_map` utilise OpenStreetMap et ne nécessite **aucune clé API**.

## Personnalisation

### Modifier le profil patient par défaut
Éditer `lib/models/patient_profile.dart` → `PatientProfile.defaultProfile`

### Changer les couleurs
Éditer `lib/theme/app_theme.dart` → classe `AppColors`

### Modifier la simulation ECG
Éditer `lib/providers/app_provider.dart` → méthode `startMonitoring()` pour changer les valeurs simulées.

---

*Prototype académique — Application de démonstration uniquement.*
*Ne pas utiliser à des fins médicales réelles.*
