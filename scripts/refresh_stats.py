# Rafraîchit les compteurs globaux dans Firestore (doc stats/global).
# Utilise count() exact — le dashboard les affiche (les queries client
# limitées à 500 étaient fausses).
import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    firebase_admin.initialize_app(
        credentials.Certificate(r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json'))
db = firestore.client()

COLLECTIONS = [
    'users',
    'receipts',
    'pharmacies',
    'medications',
    'priceEntries',
    'catalogProducts',
    'campaigns',
    'announcements',
    'mergeCandidates',
]

stats = {}
for coll in COLLECTIONS:
    try:
        result = db.collection(coll).count().get()
        count = result[0][0].value
    except Exception as e:
        print(f'  {coll}: ERREUR {e}')
        count = -1
    stats[coll] = count
    print(f'  {coll:20s} {count}')

# Extraits : prix officiels vs scannés, produits en stock.
try:
    official = db.collection('priceEntries') \
        .where(filter=firestore.FieldFilter('pharmacyId', '==', 'public-price-ci')) \
        .count().get()
    stats['priceEntriesOfficial'] = official[0][0].value
    print(f'  {"priceEntriesOfficial":20s} {stats["priceEntriesOfficial"]}')
except Exception as e:
    stats['priceEntriesOfficial'] = -1

try:
    instock = db.collection('catalogProducts') \
        .where(filter=firestore.FieldFilter('inStock', '==', True)) \
        .count().get()
    stats['catalogInStock'] = instock[0][0].value
    print(f'  {"catalogInStock":20s} {stats["catalogInStock"]}')
except Exception as e:
    stats['catalogInStock'] = -1

stats['updatedAt'] = firestore.SERVER_TIMESTAMP
db.collection('stats').document('global').set(stats, merge=True)
print('\n✅ stats/global écrit.')
