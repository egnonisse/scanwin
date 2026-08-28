# Normalisation des communes des pharmacies vers la LISTE OFFICIELLE
# DGDDL (data/communes_officielles_ci.json — 201 communes de la CI).
#
# Règle LEO : AUCUNE pharmacie ne doit être classée hors de ces communes.
#   1. Commune officielle dans le champ → nom officiel
#   2. Quartier d'Abidjan connu → commune correspondante
#   3. Sinon (adresse pure, date de garde, téléphone) → champ VIDÉ
#      (l'adresse détaillée reste dans le champ address séparé)
#
# Mode : --apply pour écrire, sinon dry-run.
import json
import re
import sys
import unicodedata

import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    firebase_admin.initialize_app(
        credentials.Certificate(r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json'))
db = firestore.client()

OFFICIAL = json.load(
    open(r'C:\Users\LEO\projects\pharmascan\data\communes_officielles_ci.json',
         encoding='utf-8'))

# Quartiers d'Abidjan → commune officielle (découpage administratif).
QUARTIERS_ABIDJAN = {
    'II PLATEAUX': 'COCODY',
    'RIVIERA': 'COCODY',
    'AKOUEDO': 'COCODY',
    'PALMERAIE': 'COCODY',
    'ANGRE': 'COCODY',
    'DJIBI': 'COCODY',
    'ABATTA': 'COCODY',
    'WILLIAMSVILLE': 'ADJAME',
    'VRIDI': 'PORT BOUET',
    'ADJOUFFOU': 'PORT BOUET',
    'GONZAGUEVILLE': 'PORT BOUET',
    'TOIT ROUGE': 'YOPOUGON',
    'WASSAKARA': 'YOPOUGON',
    'SICOGI': 'YOPOUGON',
    'NIANGON': 'YOPOUGON',
    'BANCO': 'ATTECOUBE',
    'ABOBODOUME': 'YOPOUGON',
    'LOCODJORO': 'YOPOUGON',
    'ANONO': 'COCODY',
    'ALLABIA': 'YOPOUGON',
    'AZITO': 'YOPOUGON',
    'SELMER': 'YOPOUGON',
    'BAGNON': 'YOPOUGON',
    'SIPOREX': 'YOPOUGON',
}

DATE_GARDE_RE = re.compile(
    r'(LUNDI|MARDI|MERCREDI|JEUDI|VENDREDI|SAMEDI|DIMANCHE)', re.IGNORECASE)
PHONE_RE = re.compile(r'\b\d{2}\s*\d{2}\s*\d{2}\s*\d{2}\s*\d{2}\b')

ACCENTS = {
    'ABENGOUROU': 'Abengourou', 'ABOBO': 'Abobo', 'ABOISSO': 'Aboisso',
    'ADIAKE': 'Adiaké', 'ADJAME': 'Adjamé', 'ADZOPE': 'Adzopé',
    'AFFERY': 'Afféry', 'AGBOVILLE': 'Agboville', 'AGNIBILEKRO': 'Agnibilékro',
    'AGOU': 'Agou', 'ANYAMA': 'Anyama', 'ATTECOUBE': 'Attécoubé',
    'BINGERVILLE': 'Bingerville', 'BOUAKE': 'Bouaké', 'BOUAFLE': 'Bouaflé',
    'COCODY': 'Cocody', 'DALOA': 'Daloa', 'DANANE': 'Danané',
    'DUEKOUE': 'Duékoué', 'GRAND BASSAM': 'Grand-Bassam', 'HIRE': 'Hiré',
    'ISSA': 'Issia', 'KORHOGO': 'Korhogo', 'KOUMASSI': 'Koumassi',
    'MARCORY': 'Marcory', 'ODIENNE': 'Odienné', 'PLATEAU': 'Plateau',
    'PORT BOUET': 'Port-Bouët', 'SAN PEDRO': 'San-Pédro', 'SEGUELA': 'Séguéla',
    'SONGON': 'Songon', 'TREICHVILLE': 'Treichville', 'YOPOUGON': 'Yopougon',
    'YAMOUSSOUKRO': 'Yamoussoukro', 'ZOUAN HOUNIEN': 'Zouan-Hounien',
    'ALEPE': 'Alépé', 'FERKESSEDOUGOU': 'Ferkessédougou',
}


def strip_accents(s: str) -> str:
    s = unicodedata.normalize('NFD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return s.upper()


def norm_key(s: str) -> str:
    """Clé de comparaison : accents et tirets neutralisés."""
    s = strip_accents(s)
    s = re.sub(r"['’]", ' ', s)
    s = re.sub(r'[^A-Z0-9]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def display(official_name: str) -> str:
    return ACCENTS.get(official_name, official_name.title())


def normalize_commune(raw: str):
    """Retourne la commune officielle (display) ou None si non résolue."""
    if not raw:
        return None
    s = raw.upper().strip()
    s = re.sub(r'\(.*?\)', ' ', s)
    if DATE_GARDE_RE.search(s) and len(s.split()) < 12:
        return None
    s = re.sub(PHONE_RE, ' ', s)
    key = norm_key(s)
    if not key:
        return None

    # 1. Quartiers d'Abidjan (avant les communes : II PLATEAUX → Cocody).
    for quartier, commune in sorted(QUARTIERS_ABIDJAN.items(), key=lambda kv: -len(kv[0])):
        if re.search(r'\b' + re.escape(norm_key(quartier)) + r'\b', key):
            return display(commune)

    # 2. Commune officielle par mot entier.
    for commune in sorted(OFFICIAL, key=len, reverse=True):
        if re.search(r'\b' + re.escape(norm_key(commune)) + r'\b', key):
            return display(commune)

    # 3. Non résolue (adresse pure) → vider.
    return None


def main():
    apply_mode = '--apply' in sys.argv
    docs = list(db.collection('pharmacies').stream())
    report = {'updated': [], 'cleared': [], 'kept': 0}
    batch = db.batch()

    for d in docs:
        data = d.to_dict()
        raw = (data.get('commune') or '').strip()
        normalized = normalize_commune(raw)

        if normalized is None:
            if raw:
                report['cleared'].append((d.id, raw))
                if apply_mode:
                    batch.update(d.reference, {'commune': ''})
            else:
                report['kept'] += 1
            continue

        if normalized.upper() == strip_accents(raw):
            report['kept'] += 1
            continue

        report['updated'].append((d.id, raw, normalized))
        if apply_mode:
            batch.update(d.reference, {'commune': normalized})

    if apply_mode and (report['updated'] or report['cleared']):
        batch.commit()

    print(f"== RAPPORT {'APPLIQUÉ' if apply_mode else 'DRY-RUN'} ==")
    print(f"  Normalisées : {len(report['updated'])}")
    print(f"  Vidées (adresse pure) : {len(report['cleared'])}")
    print(f"  Inchangées : {report['kept']}")
    if report['updated']:
        print('\nTransformations :')
        for doc_id, old, new in report['updated'][:40]:
            print(f"  '{old[:50]}' → '{new}'")
    if report['cleared']:
        print('\nVidées :')
        for doc_id, old in report['cleared'][:40]:
            print(f"  '{old[:50]}' → (vide)")
    if not apply_mode:
        print('\n→ Relancer avec --apply pour écrire.')


if __name__ == '__main__':
    main()
