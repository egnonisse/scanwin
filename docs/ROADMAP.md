# PharmaScan — Roadmap de développement

*Validé le 27/08/2026 — priorité : phase 0 (production) puis phase 1 (base de prix).*

## 🟢 PHASE 0 — Production (bloquant)

| # | Feature | Statut |
|---|---------|--------|
| 0.1 | Crashlytics | ⏳ à faire (30 min) |
| 0.2 | Test fermé 14j (12 testeurs) | ⏳ recrutement en cours |
| 0.3 | Fiche Play complète (icône ✅, 6 screenshots) | ⏳ à recapturer |
| 0.4 | Firebase App Check | ⏳ à configurer |
| 0.5 | Demande de production | ⏳ après 0.1-0.4 |

## 🔵 PHASE 1 — Le cœur : la base de prix

**Le produit VIT de la base de prix : un comparateur sans prix = un annuaire.**
État : 0 prix réels scannés.

| # | Feature | Statut |
|---|---------|--------|
| 1.1 | Seed de prix initial (sources officielles/partenaires) | ✅ 3 809 prix publics importés + 53 800 produits parapharmacie |
| 1.1b | Photos des produits | ⏸️ OPTION B choisie : fiche sans photo (le scraping Bing = 60-80% de bruit ; source structurée nécessaire plus tard — piste Google Custom Search API 100 req/j gratuites) |
| 1.2 | Parrainage (code → points parrain + filleul) | ⏳ |
| 1.3 | Modération IA des scans (dashboard) | ⏳ (base existante à enrichir) |
| 1.4 | Alertes prix en baisse (push) | ⏳ |

## 🟡 PHASE 2 — Engagement & fidélité

| # | Feature |
|---|---------|
| 2.1 | Récompenses réelles (bons parapharmacie, réductions partenaires) |
| 2.2 | Leaderboard local (« Top contributeurs d'Abidjan ») |
| 2.3 | Push programmés (calendrier dashboard) |
| 2.4 | Historique personnel + suivi dépenses santé |

## 🟠 PHASE 3 — Monétisation B2B

| # | Feature |
|---|---------|
| 3.1 | Espace pharmacie (réclamer sa fiche, stats) |
| 3.2 | Abonnement pharmacie (visibilité premium, ~30-75k F/mois) |
| 3.3 | Données anonymisées laboratoires (conformité ARTCI) |

## ⚪ PHASE 4 — Expansion

- iOS (TestFlight → App Store)
- Autres pays UEMOA (Sénégal, Bénin, Burkina)
- Alertes de garde personnalisées

## Ordre immédiat

1. Crashlytics (avant prod)
2. Recruter 12 testeurs (LEO — goulot)
3. Screenshots Play
4. Seed de prix (1.1 — en cours)
5. Parrainage (1.2)
