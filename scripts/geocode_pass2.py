# Passe 2 : géocodage simplifié (nom + Abidjan) pour les pharmacies sans coordonnées
import json
import time
import urllib.parse
import urllib.request

import firebase_admin
from firebase_admin import credentials, firestore

SA_KEY = r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json'
UA = {'User-Agent': 'PharmaScan/1.0 (contact: tobossinonleonard@gmail.com)'}
NOMINATIM = 'https://nominatim.openstreetmap.org/search'


def geocode(query):
    params = urllib.parse.urlencode({'q': query, 'format': 'json', 'limit': 1,
                                     'countrycodes': 'ci'})
    req = urllib.request.Request(f'{NOMINATIM}?{params}', headers=UA)
    try:
        data = json.loads(urllib.request.urlopen(req, timeout=30).read().decode())
    except Exception:
        return None
    if not data:
        return None
    return float(data[0]['lat']), float(data[0]['lon'])


if not firebase_admin._apps:
    firebase_admin.initialize_app(credentials.Certificate(SA_KEY))
db = firestore.client()

without = [p for p in db.collection('pharmacies').get() if not p.to_dict().get('lat')]
print(f'Passe 2 — sans coordonnées: {len(without)}', flush=True)

ok = 0
for p in without:
    d = p.to_dict()
    name = d.get('name', '')
    if not name:
        continue
    result = geocode(f'Pharmacie {name}, Abidjan, Côte d\'Ivoire')
    time.sleep(1.1)
    if result:
        p.reference.update({'lat': result[0], 'lng': result[1]})
        ok += 1
        continue
    result = geocode(f'{name}, Côte d\'Ivoire')
    time.sleep(1.1)
    if result:
        p.reference.update({'lat': result[0], 'lng': result[1]})
        ok += 1
    if ok % 20 == 0:
        print(f'  ... {ok} géocodées', flush=True)

print(f'Passe 2 terminée: {ok} supplémentaires', flush=True)
