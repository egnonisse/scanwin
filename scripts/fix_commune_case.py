# Homogénéise la CASSE des communes (COCODY → Cocody) après la
# normalisation vers la liste officielle.
# Idempotent. Sans argument = dry-run, --apply = écrit.
import re
import sys
import unicodedata

import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    firebase_admin.initialize_app(
        credentials.Certificate(r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json'))
db = firestore.client()

ACCENTS = {
    'ABENGOUROU': 'Abengourou', 'ABOBO': 'Abobo', 'ABOISSO': 'Aboisso',
    'ADIAKE': 'Adiaké', 'ADJAME': 'Adjamé', 'ADZOPE': 'Adzopé',
    'AFFERY': 'Afféry', 'AGBOVILLE': 'Agboville', 'AGNIBILEKRO': 'Agnibilékro',
    'AGOU': 'Agou', 'ANYAMA': 'Anyama', 'ATTECOUBE': 'Attécoubé',
    'ATTIEGOUAKRO': 'Attiegouakro', 'BINGERVILLE': 'Bingerville',
    'BONOUA': 'Bonoua', 'BOUAKE': 'Bouaké', 'BOUAFLE': 'Bouaflé',
    'COCODY': 'Cocody', 'DABOU': 'Dabou', 'DALOA': 'Daloa',
    'DANANE': 'Danané', 'DIEGONEFLA': 'Diégonéfla', 'DIVO': 'Divo',
    'DUEKOUE': 'Duékoué', 'GRAND BASSAM': 'Grand-Bassam',
    'GRAND-BASSAM': 'Grand-Bassam', 'GUIGLO': 'Guiglo', 'HIRE': 'Hiré',
    'ISSIA': 'Issia', 'KATIOLA': 'Katiola', 'KORHOGO': 'Korhogo',
    'KOUMASSI': 'Koumassi', 'MAN': 'Man', 'MARCORY': 'Marcory',
    'ODIENNE': 'Odienné', 'PLATEAU': 'Plateau', 'PORT BOUET': 'Port-Bouët',
    'PORT-BOUET': 'Port-Bouët', 'SAN PEDRO': 'San-Pédro', 'SAN-PEDRO': 'San-Pédro',
    'SEGUELA': 'Séguéla', 'SINFRA': 'Sinfra', 'SONGON': 'Songon',
    'SOUBRE': 'Soubré', 'TIASSALE': 'Tiassalé', 'TREICHVILLE': 'Treichville',
    'YOPOUGON': 'Yopougon', 'YAMOUSSOUKRO': 'Yamoussoukro',
    'ZOUAN HOUNIEN': 'Zouan-Hounien', 'ALEPE': 'Alépé',
    'FERKESSEDOUGOU': 'Ferkessédougou',
}


def strip_accents(s: str) -> str:
    s = unicodedata.normalize('NFD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return s.upper()


def display(value: str) -> str:
    key = re.sub(r'[^A-Z0-9]+', ' ', strip_accents(value)).strip()
    return ACCENTS.get(key, value.title())


def main():
    apply_mode = '--apply' in sys.argv
    docs = list(db.collection('pharmacies').stream())
    updates = []
    batch = db.batch()
    for d in docs:
        raw = (d.to_dict().get('commune') or '').strip()
        if not raw:
            continue
        pretty = display(raw)
        if pretty != raw:
            updates.append((d.id, raw, pretty))
            if apply_mode:
                batch.update(d.reference, {'commune': pretty})
    if apply_mode and updates:
        batch.commit()
    print(f"== CASSE {'APPLIQUÉE' if apply_mode else 'DRY-RUN'} ==")
    print(f'  {len(updates)} communes à homogénéiser')
    for doc_id, old, new in updates:
        print(f"  '{old}' → '{new}'")
    if not apply_mode:
        print('→ Relancer avec --apply')


if __name__ == '__main__':
    main()
