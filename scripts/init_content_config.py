# Initialise contentConfig/default : liste des groupes thérapeutiques
# distincts (pour la gestion par catégorie du dashboard) + listes vides
# de masquage. Idempotent : conserve les filtres existants.
import json

import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    firebase_admin.initialize_app(
        credentials.Certificate(r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json'))
db = firestore.client()

data = json.load(open('data/medicament_prices_ci.json', encoding='utf-8'))
categories = sorted({m['therapeutic_group'] for m in data if m.get('therapeutic_group')})
print(f'{len(categories)} groupes thérapeutiques distincts')

ref = db.collection('contentConfig').document('default')
doc = ref.get()
if doc.exists:
    ref.update({'categories': categories})
    print('Mis à jour (filtres existants conservés).')
else:
    ref.set({
        'categories': categories,
        'hiddenMedications': [],
        'disabledCategories': [],
    })
    print('Créé avec listes de masquage vides.')
