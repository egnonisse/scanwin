# Import du seed de prix officiels dans Firestore (priceEntries).
#
# Chaque entrée = un médicament avec son prix public CI (source :
# pharmacies-de-garde.ci, liste des prix en pharmacie).
# pharmacyId = 'public-price-ci' (prix de référence officiel, pas une
# pharmacie physique) — l'app le compare aux prix scannés réels.
#
# Idempotent : supprime les entrées précédentes de cette source puis
# réécrit (l'import repart de zéro à chaque exécution).
import json
import re
import unicodedata

import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    firebase_admin.initialize_app(
        credentials.Certificate(r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json'))
db = firestore.client()

SOURCE_PHARMACY_ID = 'public-price-ci'
SOURCE_PHARMACY_NAME = 'Prix public officiel'


def normalize(value: str) -> str:
    """Même normalisation que la Cloud Function (recherche)."""
    s = value.strip().lower()
    s = unicodedata.normalize('NFD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r'[^a-z0-9]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def main():
    data = json.load(open('data/medicament_prices_ci.json', encoding='utf-8'))
    print(f'{len(data)} médicaments à importer')

    # 1. Purge des entrées précédentes de cette source (idempotence).
    old = db.collection('priceEntries') \
        .where('pharmacyId', '==', SOURCE_PHARMACY_ID) \
        .stream()
    deleted = 0
    batch = db.batch()
    for doc in old:
        batch.delete(doc.reference)
        deleted += 1
        if deleted % 450 == 0:
            batch.commit()
            batch = db.batch()
    if deleted % 450 != 0:
        batch.commit()
    print(f'{deleted} anciennes entrées supprimées')

    # 2. Écriture des nouvelles entrées (batch de 450).
    written = 0
    batch = db.batch()
    for m in data:
        doc_id = f'seed-{normalize(m["name"])}-{m["price_xof"]:.0f}'[:100]
        ref = db.collection('priceEntries').document(doc_id)
        batch.set(ref, {
            'medicationName': normalize(m['name']),
            'displayName': m['name'],
            'pharmacyId': SOURCE_PHARMACY_ID,
            'pharmacyName': SOURCE_PHARMACY_NAME,
            'price': m['price_xof'],
            'quantity': 1,
            'therapeuticGroup': m.get('therapeutic_group', ''),
            'code': m.get('code', ''),
            'scannedAt': firestore.SERVER_TIMESTAMP,
            'source': 'pharmacies-de-garde.ci',
        })
        written += 1
        if written % 450 == 0:
            batch.commit()
            batch = db.batch()
    if written % 450 != 0:
        batch.commit()

    print(f'✅ {written} prix importés dans priceEntries '
          f'(pharmacyId={SOURCE_PHARMACY_ID})')


if __name__ == '__main__':
    main()
