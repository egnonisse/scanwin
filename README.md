# scanWin

Ce dépôt contient la spec (`.md`) et le bootstrap du projet Flutter.

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

