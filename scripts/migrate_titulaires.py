# Migration : ajoute le champ 'titulaire' aux 13 601 médicaments existants
# (update par CIS — pas de doublon).
import codecs

import firebase_admin
from firebase_admin import credentials, firestore

SA_KEY = r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json'
CIS_FILE = r'C:\Users\LEO\AppData\Local\Temp\CIS_bdpm.txt'


def parse_titulaires(path: str) -> dict:
    """CIS → titulaire."""
    out = {}
    with codecs.open(path, 'r', 'latin-1') as f:
        for line in f:
            fields = line.rstrip('\n').split('\t')
            if len(fields) > 10:
                cis = fields[0].strip()
                titulaire = fields[10].strip()
                if cis and titulaire:
                    out[cis] = titulaire
    return out


if not firebase_admin._apps:
    firebase_admin.initialize_app(credentials.Certificate(SA_KEY))
db = firestore.client()

print('Parsing des titulaires...')
titulaires = parse_titulaires(CIS_FILE)
print(f'  {len(titulaires)} CIS → titulaires')

print('Migration Firestore (update par cis)...')
meds = db.collection('medications').get()
batch = db.batch()
count = 0
updated = 0
for doc in meds:
    data = doc.to_dict()
    cis = data.get('cis')
    if cis and cis in titulaires and not data.get('titulaire'):
        batch.update(doc.reference, {'titulaire': titulaires[cis]})
        count += 1
        updated += 1
        if count >= 400:
            batch.commit()
            batch = db.batch()
            count = 0
            print(f'  ... {updated} mis à jour')
if count > 0:
    batch.commit()

print(f'Migration terminée : {updated} médicaments avec titulaire')
