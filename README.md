# Pharmascan

Application mobile (Flutter) qui aide les utilisateurs à :

1. **Trouver les pharmacies de garde** selon la localisation et la date
2. **Comparer les prix des médicaments** entre pharmacies, grâce aux reçus scannés par la communauté

## Fonctionnement

- L'utilisateur **scanne son reçu de pharmacie** (caméra → OCR on-device ML Kit)
- L'OCR extrait : pharmacie, date, liste des médicaments et leurs prix
- L'utilisateur **corrige** les données extraites (l'OCR seul n'est jamais fiable à 100 %)
- La Cloud Function `submitReceipt` **garantit l'unicité** (un reçu = une soumission) et crédite des points
- Les prix sont agrégés dans `priceEntries` pour la **recherche par médicament triée par prix**

## Structure du dépôt

- la spec technique (`.md`) — scan/OCR, conformité Play Store & App Store
- l'app mobile Flutter (`ticket_scanner/`)
- le backend Cloud Functions (`functions/`) — `submitReceipt`
- les règles Firestore (`firestore.rules`)
- l'admin web Flutter (`admin_web/`, prévu)

## Firebase (important)

- **Le seul fichier de déploiement Firebase** est à la racine : `firebase.json`
  - il configure `functions/` et les règles Firestore
- Le mapping projet est à la racine : `.firebaserc` (projet `boostsocial-a7720`)

Objectif : éviter toute confusion avec des fichiers "firebase.json" générés par d'autres outils dans des sous-dossiers.

## Modèle de données

```
pharmacies/{slug}           : name, createdAt (créée automatiquement au premier reçu)
receipts/{hash}             : pharmacyId, scannedBy, scannedAt, dateTicket, montant, items[]
priceEntries/{autoId}       : medicationName, pharmacyId, price, quantity, scannedAt, receiptId
users/{uid}                 : points, currencyCode, createdAt
users/{uid}/pointsEvents/{id} : pointsAdded, receiptId, montant, createdAt
```

## Pré-requis (Windows)

- Installer Flutter et l'ajouter au `PATH`
- Vérifier : `flutter --version`

## Démarrage rapide

```powershell
.\scripts\bootstrap.ps1
```

## Feuille de route

- [x] Socle : auth anonyme, splash, home (points), réglages (devise)
- [x] Scan reçu + OCR + édition manuelle
- [x] Backend : `submitReceipt` (unicité + priceEntries + points) + règles Firestore
- [ ] Pharmacies de garde (saisie admin + affichage)
- [ ] Recherche médicament (tri par prix)
- [ ] Admin web (saisie pharmacies, modération)
- [ ] Déploiement Firebase + stores
