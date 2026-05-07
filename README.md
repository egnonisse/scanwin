# scanWin

Ce dépôt contient :
- la spec (`.md`)
- l’app mobile Flutter (`ticket_scanner/`)
- l’admin web Flutter (`admin_web/`)
- le backend (Cloud Functions) (`functions/`)

## Firebase (important)

- **Le seul fichier de déploiement Firebase** est à la racine : `firebase.json`
  - il configure `functions/` et le hosting pour servir `admin_web/build/web`
- Le mapping projet est à la racine : `.firebaserc`

Objectif : éviter toute confusion avec des fichiers “firebase.json” générés par d’autres outils dans des sous-dossiers.

## Pré-requis (Windows)

- Installer Flutter et l’ajouter au `PATH`
- Vérifier :

```powershell
flutter --version
```

## Démarrage rapide

Dans PowerShell, à la racine :

```powershell
.\scripts\bootstrap.ps1
```

Ce script :
- vérifie que `flutter` est disponible
- crée le projet `ticket_scanner` si absent
- (étape suivante) posera l’architecture `lib/features/*` et la config “devise paramétrable”

