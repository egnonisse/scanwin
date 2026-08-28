# Import du catalogue parapharmacie (pharmacie-ivoirienne.com) dans
# Firestore, collection dédiée catalogProducts (PAS priceEntries qui reste
# réservé aux médicaments).
#
# Idempotent : purge la source puis réécrit.
import json
import re
import unicodedata

import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    firebase_admin.initialize_app(
        credentials.Certificate(r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json'))
db = firestore.client()

SOURCE = 'pharmacie-ivoirienne.com'


def normalize(value: str) -> str:
    s = value.strip().lower()
    s = unicodedata.normalize('NFD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r'[^a-z0-9]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def main():
    data = json.load(open('data/piv_products_full.json', encoding='utf-8'))
    priced = [p for p in data if p['price_xof'] > 0]
    print(f'{len(priced)} produits avec prix à importer')

    # 1. Purge (idempotence).
    old = db.collection('catalogProducts') \
        .where(filter=firestore.FieldFilter('source', '==', SOURCE)) \
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

    # 2. Écriture (batch 450).
    written = 0
    batch = db.batch()
    for p in priced:
        name = p['name']
        doc_id = f'piv-{normalize(name)}-{int(p["price_xof"])}'[:100]
        ref = db.collection('catalogProducts').document(doc_id)
        batch.set(ref, {
            'name': name,
            'normalizedName': normalize(name),
            'price': p['price_xof'],
            'categories': p.get('categories', []),
            'brands': p.get('brands', []),
            'inStock': p.get('in_stock', False),
            'url': p.get('url', ''),
            'source': SOURCE,
            'createdAt': firestore.SERVER_TIMESTAMP,
        })
        written += 1
        if written % 450 == 0:
            batch.commit()
            batch = db.batch()
    if written % 450 != 0:
        batch.commit()

    print(f'✅ {written} produits parapharmacie importés (catalogProducts)')


if __name__ == '__main__':
    main()
