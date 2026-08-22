# PharmaScan — Design System Guideline

> Validé par LEO le 20/08/2026 · Slogan officiel : **« Comparez. Payez juste. »**
> Source de vérité : `ticket_scanner/lib/core/theme/app_theme.dart` (app) et
> `admin_web/lib/core/theme/app_theme.dart` (dashboard) — ces fichiers font foi
> en cas de divergence avec ce document.

## 1. Couleurs

### Palette principale

| Jeton | Valeur | Usage |
|---|---|---|
| `primary` | `#0E7A5F` | Boutons pleins, AppBar, éléments actifs, liens |
| `secondary` | `#19B28A` | Dégradés, accents, tags |
| `background` | `#F8FAF9` | Arrière-plan général (blanc cassé) |
| `surface` | `#FFFFFF` | Cartes, champs de saisie |
| `onPrimary` | `#FFFFFF` | Texte sur fond vert |

### Textes

| Jeton | Valeur | Usage |
|---|---|---|
| `textPrimary` | `#1A2E28` | Titres et corps principaux |
| `textSecondary` | `#6B7D75` | Descriptions, dates |
| `textMuted` | `#8A9A93` | Hints, placeholders |

### Niveaux contributeur

| Niveau | Couleur |
|---|---|
| Bronze | `#9C6B30` |
| Argent | `#8E9AAF` |
| Or | `#D4AF37` |

### Composants

| Composant | Valeur |
|---|---|
| AppBar (dégradé) | `#0E7A5F → #0A5C48` |
| Scanner (fond caméra) | fond `#1A2E28` · cadre `#7EE0C8` |
| Erreur | `#B3261E` |
| Divider | `#F0F4F2` |

## 2. Typographie

| Rôle | Police | Taille | Graisse |
|---|---|---|---|
| Grand titre (`headlineSmall`) | **Poppins** | 22 | 600 |
| Titre page (`titleLarge`) | **Poppins** | 17 | 600 |
| Titre section (`titleMedium`) | **Poppins** | 14 | 600 |
| Petit titre (`titleSmall`) | **Poppins** | 12 | 500 |
| Corps (`bodyLarge`) | **Inter** | 14 | 400 |
| Corps (`bodyMedium`) | **Inter** | 13 | 400 |
| Légende (`bodySmall`) | **Inter** | 11 | 400 |
| Boutons (`labelLarge`) | **Poppins** | 14 | 600 |

- **Poppins** = titres, noms, valeurs, boutons (impact, lisibilité).
- **Inter** = corps de texte, descriptions, dates.
- Polices **embarquées localement** (`assets/fonts/`) — jamais de téléchargement
  réseau au runtime (leçon : app figée sur réseau lent).

## 3. Formes (rayons)

| Élément | Rayon |
|---|---|
| Cartes | **5px** |
| Boutons | **5px** |
| Champs de saisie | **5px** |
| Chips / tags | **5px** |
| Icônes en conteneur | **5px** |
| **AppBar** | **0 (carrée)** |

Règle : 5px partout, AppBar carrée. Pas de coins très arrondis (12px+) nulle part.

## 4. Ombres

| Contexte | Ombres |
|---|---|
| Carte | `0 1px 3px` (flou 3, offset y 1, très douce) |
| Searchbar | `0 1px 3px` |

Règle : ombres **discrètes** — jamais d'ombres lourdes ni d'élévation forte.

## 5. Composants clés

### AppBar
- Dégradé `#0E7A5F → #0A5C48`
- **Carrée** (aucun arrondi)
- Titre Poppins 17 semi-bold blanc, aligné à gauche
- Sur la home : titre « PharmaScan » + slogan « Comparez. Payez juste. » en petit (11, blanc 70 %)

### Searchbar (home)
- **Dans le contenu** (pas dans l'AppBar) — « Option A »
- Blanche, arrondie 5px, ombre douce, icône search à gauche

### Boutons
- Plein : fond `#0E7A5F`, texte blanc Poppins 13 semi-bold, 5px
- Outline : bordure `#CFE0D8`, texte vert, 5px

### Champs de saisie
- Remplis blancs, **sans bordure** (pas d'OutlineInputBorder gris)
- Focus : bordure verte 1.5px
- Hint Inter 14 `#8A9A93`

### Cartes
- Blanches, 5px, ombre douce (pas d'élévation Material par défaut)

## 6. Icônes

- **Material Icons** (Material Symbols Rounded dans les maquettes)
- Jamais d'emoji comme icônes d'interface

## 7. Marque

- Nom : **PharmaScan**
- Slogan : **« Comparez. Payez juste. »** — présent sur le splash et l'AppBar de la home
- Le slogan accompagne très souvent le nom dans les contenus

## 8. Cohérence app / dashboard

Le dashboard admin (`admin_web`) utilise **le même design system** : mêmes
couleurs, mêmes polices (embarquées), mêmes arrondis 5px, AppBar carrée.
Toute nouvelle page ou composant doit respecter ces règles dans les 2 projets.

## 9. Fichiers de référence

| Fichier | Rôle |
|---|---|
| `ticket_scanner/lib/core/theme/app_theme.dart` | Thème de l'app (source de vérité) |
| `admin_web/lib/core/theme/app_theme.dart` | Thème du dashboard (identique) |
| `sketches/001-sante-moderne/` | Mockups HTML (référence visuelle initiale) |
| `ticket_scanner/assets/fonts/` + `admin_web/assets/fonts/` | Polices embarquées (Poppins 400-700, Inter) |
