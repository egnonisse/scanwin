# Détection des doublons de pharmacies + écriture des candidats de fusion
# dans Firestore (collection mergeCandidates, lue par le dashboard).
#
# Score de confiance :
#   HAUTE   : nom normalisé identique + téléphone identique + commune identique
#             (ou date de garde détectée dans le champ commune)
#   MOYENNE : nom identique + téléphone identique mais communes différentes
#             (succursales probables — vérification humaine requise)
#   BASSE   : nom identique seul (pas de téléphone commun)
#
# Idempotent : les candidats sont recréés à chaque exécution.
import hashlib
import re
import unicodedata
from collections import defaultdict
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    firebase_admin.initialize_app(
        credentials.Certificate(r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json'))
db = firestore.client()

ABREVIATIONS = [
    (r'\bPHCIE\b', 'PHARMACIE'),
    (r'\bPHARM\b', 'PHARMACIE'),
    (r'\bPHAR\b', 'PHARMACIE'),
    (r'\bOFF\b', 'OFFICINE'),
    (r'\bSTE\b', 'SAINTE'),
    (r'\bST\b', 'SAINT'),
]

# Détection d'une date de garde dans le champ commune
# (ex : « SAMEDI 25 JUILLET AU SAMEDI 01 AOUT 2026: »).
DATE_GARDE_RE = re.compile(r'\b(LUNDI|MARDI|MERCREDI|JEUDI|VENDREDI|SAMEDI|DIMANCHE)\b',
                           re.IGNORECASE)


def normalize_name(name: str) -> str:
    s = name.upper().strip()
    s = unicodedata.normalize('NFD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    for pattern, replacement in ABREVIATIONS:
        s = re.sub(pattern, replacement, s)
    s = re.sub(r'[^A-Z0-9 ]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def normalize_phone(phone: str) -> str:
    return re.sub(r'\D', '', phone or '')


def stable_id(pharmacy_ids) -> str:
    key = '-'.join(sorted(pharmacy_ids))
    return hashlib.sha1(key.encode()).hexdigest()[:16]


def main():
    docs = db.collection('pharmacies').get()
    pharmacies = []
    for d in docs:
        data = d.to_dict()
        pharmacies.append({
            'id': d.id,
            'name': (data.get('name') or '').strip(),
            'phone1': (data.get('phone1') or '').strip(),
            'phone2': (data.get('phone2') or '').strip(),
            'commune': (data.get('commune') or '').strip(),
        })

    # --- Groupement par nom normalisé ---
    by_name = defaultdict(list)
    for p in pharmacies:
        key = normalize_name(p['name'])
        if key:
            by_name[key].append(p)

    candidates = []
    for norm_name, group in by_name.items():
        if len(group) < 2:
            continue

        # Téléphones communs (numéros complets uniquement, >= 8 chiffres).
        phones = defaultdict(list)
        for p in group:
            for phone in (p['phone1'], p['phone2']):
                digits = normalize_phone(phone)
                if len(digits) >= 8:
                    phones[digits].append(p['id'])

        # Sous-groupes qui partagent le même téléphone.
        phone_clusters = []
        used_ids = set()
        for digits, ids in phones.items():
            uniq = sorted(set(ids))
            if len(uniq) > 1:
                if not any(i in used_ids for i in uniq):
                    phone_clusters.append(uniq)
                    used_ids.update(uniq)

        if phone_clusters:
            for cluster in phone_clusters:
                members = [p for p in group if p['id'] in cluster]
                communes = {p['commune'].lower() for p in members}
                has_garde_date = any(
                    DATE_GARDE_RE.search(p['commune']) for p in members)

                # Même commune (hors repères) OU date de garde détectée →
                # doublon quasi certain.
                if len(communes) == 1 or has_garde_date:
                    score = 'high'
                    reason = ('même nom + même téléphone + même commune'
                              if len(communes) == 1
                              else 'même nom + même téléphone + date de garde')
                else:
                    score = 'medium'
                    reason = 'même nom + même téléphone mais communes différentes'
                candidates.append({
                    'pharmacyIds': cluster,
                    'names': [p['name'] for p in members],
                    'communes': [p['commune'] for p in members],
                    'score': score,
                    'reason': reason,
                })
        else:
            # Même nom, pas de téléphone commun → faible confiance.
            candidates.append({
                'pharmacyIds': [p['id'] for p in group],
                'names': [p['name'] for p in group],
                'communes': [p['commune'] for p in group],
                'score': 'low',
                'reason': 'même nom normalisé, pas de téléphone commun',
            })

    # --- Écriture dans mergeCandidates (idempotent) ---
    batch = db.batch()
    existing = db.collection('mergeCandidates').get()
    for doc in existing:
        batch.delete(doc.reference)

    now = datetime.now(timezone.utc)
    for c in candidates:
        cid = stable_id(c['pharmacyIds'])
        batch.set(db.collection('mergeCandidates').document(cid), {
            'pharmacyIds': c['pharmacyIds'],
            'names': c['names'],
            'communes': c['communes'],
            'score': c['score'],
            'reason': c['reason'],
            'status': 'pending',
            'createdAt': now,
        })

    batch.commit()

    high = sum(1 for c in candidates if c['score'] == 'high')
    medium = sum(1 for c in candidates if c['score'] == 'medium')
    low = sum(1 for c in candidates if c['score'] == 'low')
    print(f'=== RÉSULTAT DÉTECTION (mergeCandidates écrits) ===')
    print(f'HAUTE confiance : {high} groupe(s) — fusion quasi sûre')
    print(f'MOYENNE : {medium} groupe(s) — succursales probables, à vérifier')
    print(f'BASSE : {low} groupe(s) — même nom seul, à vérifier')
    print(f'TOTAL : {len(candidates)} candidat(s) → collection mergeCandidates')

    if high:
        print('\nDétail HAUTE confiance :')
        for c in candidates:
            if c['score'] == 'high':
                print(f"  - {c['names'][0]} | {c['communes'][0]} "
                      f"({len(c['pharmacyIds'])} entrées)")


if __name__ == '__main__':
    main()
