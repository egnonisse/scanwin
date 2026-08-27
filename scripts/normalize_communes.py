# Harmonisation des communes des pharmacies PharmaScan.
#
# Le champ commune contient du bruit : adresses détaillées, dates de garde,
# téléphones. On normalise vers la COMMUNE OFFICIELLE :
#   1. Nettoyage (dates de garde, numéros de téléphone)
#   2. Correspondance quartier → commune (Abidjan) via un mapping connu
#   3. Correspondance exacte avec la liste officielle des communes CI
#   4. Capitalisation propre (title case)
#
# Mode : --apply pour écrire, sinon dry-run (rapport uniquement).
import re
import sys
import unicodedata

import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    firebase_admin.initialize_app(
        credentials.Certificate(r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json'))
db = firestore.client()

# Communes officielles de Côte d'Ivoire (source : données présentes dans la
# base + découpage administratif standard).
COMMUNES_OFFICIELLES = {
    'ABIDJAN', 'ABOBO', 'ADJAME', 'ATTECOUBE', 'COCODY', 'KOUMASSI',
    'MARCORY', 'PLATEAU', 'PORT-BOUET', 'TREICHVILLE', 'YOPOUGON',
    'ANYAMA', 'BINGERVILLE', 'SONGON', 'GRAND-BASSAM',
    'ABENGOUROU', 'ABOISSO', 'ADIAKE', 'ADZOPE', 'AGBOVILLE',
    'AGNIBILEKRO', 'BONDOUKOU', 'BONOUA', 'BOUAFLE', 'BOUAKE',
    'BOUNDIALI', 'DABOU', 'DALOA', 'DANANE', 'DIMBOKRO', 'DIVO',
    'DUEKOUE', 'FERKESSEDOUGOU', 'GAGNOA', 'GUIGLO', 'ISSA',
    'ISSIA', 'KATIOLA', 'KORHOGO', 'MAN', 'ODIENNE', 'SAN-PEDRO',
    'SEGUELA', 'SINFRA', 'SOUBRE', 'TIASSALE', 'TOUMODI',
    'YAMOUSSOUKRO', 'BONGOUANOU', 'DAOUKRO', 'LAKOTA', 'MANKONO',
    'MINIGNAN', 'SASSANDRA', 'TABOU', 'TOULEPLEU', 'ARRAH',
    'BAYOTA', 'HIRE', 'ALEPE',
}

# Quartiers d'Abidjan → commune officielle (découpage administratif).
QUARTIERS_ABIDJAN = {
    'II PLATEAUX': 'COCODY',
    'RIVIERA': 'COCODY',
    'AKOUEDO': 'COCODY',
    'PALMERAIE': 'COCODY',
    'ANGRE': 'COCODY',
    'DJIBI': 'COCODY',
    'WILLIAMSVILLE': 'ADJAME',
    'ADJAME CENTRE': 'ADJAME',
    'ABOBO': 'ABOBO',
    'VRIDI': 'PORT-BOUET',
    'ADJOUFFOU': 'PORT-BOUET',
    'GONZAGUEVILLE': 'PORT-BOUET',
    'MARCORY NORD': 'MARCORY',
    'MARCORY SUD': 'MARCORY',
    'MARCORY': 'MARCORY',
    'KOUMASSI': 'KOUMASSI',
    'YOPOUGON': 'YOPOUGON',
    'TOIT ROUGE': 'YOPOUGON',
    'WASSAKARA': 'YOPOUGON',
    'SICOGI': 'YOPOUGON',
    'NIANGON': 'YOPOUGON',
    'TREICHVILLE': 'TREICHVILLE',
    'PLATEAU': 'PLATEAU',
    'ATTECOUBE': 'ATTECOUBE',
    'BANCO': 'ATTECOUBE',
    'ANYAMA': 'ANYAMA',
    'BINGERVILLE': 'BINGERVILLE',
    'SONGON': 'SONGON',
    'GRAND-BASSAM': 'GRAND-BASSAM',
    'BASSAM': 'GRAND-BASSAM',
}

DATE_GARDE_RE = re.compile(
    r'(LUNDI|MARDI|MERCREDI|JEUDI|VENDREDI|SAMEDI|DIMANCHE)',
    re.IGNORECASE,
)
PHONE_IN_COMMUNE_RE = re.compile(r'\b\d{2}\s*\d{2}\s*\d{2}\s*\d{2}\s*\d{2}\b')


def strip_accents(s: str) -> str:
    s = unicodedata.normalize('NFD', s)
    return ''.join(c for c in s if not unicodedata.combining(c)).upper()


def title_case(s: str) -> str:
    """Capitalise proprement : « SAN-PEDRO » → « San-Pédro »."""
    parts = re.split(r'([ -])', s)
    return ''.join(
        p.capitalize() if p.isalpha() else p for p in parts
    )


ACCENT_MAP = {'E': 'É', 'E': 'È', 'O': 'Ô', 'U': 'Û', 'A': 'À', 'I': 'Î'}


def restore_accents(name: str) -> str:
    """Remet les accents des noms officiels connus."""
    fixes = {
        'San-Pedro': 'San-Pédro',
        'Adjame': 'Adjamé',
        'Attecoube': 'Attécoubé',
        'Agnibilekro': 'Agnibilékro',
        'Duekoue': 'Duékoué',
        'Seguela': 'Séguéla',
        'Bouake': 'Bouaké',
        'Odienne': 'Odienné',
        'Adzope': 'Adzopé',
        'Bouafle': 'Bouaflé',
        'Danane': 'Danané',
        'Yamoussoukro': 'Yamoussoukro',
        'Port-Bouet': 'Port-Bouët',
        'Alepe': 'Alépé',
        'Hire': 'Hiré',
    }
    return fixes.get(name, name)


def normalize_commune(raw: str):
    """Retourne la commune officielle ou None si introuvable."""
    if not raw:
        return None

    # 1. Nettoyage : tout ce qui suit un '/' est un repère d'adresse.
    s = raw.upper().strip()
    s = re.sub(r'\(.*?\)', ' ', s)
    # Les dates de garde polluent : si le champ EST une date de garde, pas
    # une commune.
    if DATE_GARDE_RE.search(s) and len(s.split()) < 12:
        return None
    s = re.sub(PHONE_IN_COMMUNE_RE, ' ', s)

    text_clean = strip_accents(s)

    # 2. Correspondance quartier → commune (AVANT les communes : « II
    # PLATEAUX » doit matcher le quartier Cocody, pas la commune Plateau).
    for quartier, commune in sorted(
        QUARTIERS_ABIDJAN.items(), key=lambda kv: -len(kv[0])):
        if re.search(r'\b' + re.escape(strip_accents(quartier)) + r'\b',
                     text_clean):
            return commune

    # 3. Commune officielle : match par MOT ENTIER (word boundary) — évite
    # « PLATEAU » dans « PLATEAUX » ou « ABOBO » dans « ABOBODOUME ».
    for commune in sorted(COMMUNES_OFFICIELLES, key=len, reverse=True):
        if re.search(r'\b' + re.escape(strip_accents(commune)) + r'\b',
                     text_clean):
            return restore_accents(title_case(commune))

    # 4. Aucune correspondance : champ non normalisable (adresse pure).
    return None


def main():
    apply_mode = '--apply' in sys.argv
    docs = list(db.collection('pharmacies').get())
    report = {'updated': [], 'cleared': [], 'kept': 0}
    batch = db.batch()

    for d in docs:
        data = d.to_dict()
        raw = (data.get('commune') or '').strip()
        normalized = normalize_commune(raw)

        if normalized is None:
            if raw:
                # Adresse pure, pas de commune identifiable : on garde le
                # champ (il contient l'adresse, utile ailleurs) mais on le
                # signale.
                report['kept'] += 1
            else:
                report['kept'] += 1
            continue

        if normalized.upper() == strip_accents(raw):
            report['kept'] += 1
            continue

        if normalized and normalized != raw:
            report['updated'].append((d.id, raw, normalized))
            if apply_mode:
                batch.update(d.reference, {'commune': normalized})

    if apply_mode and report['updated']:
        batch.commit()

    print(f"== RAPPORT {'APPLIQUÉ' if apply_mode else 'DRY-RUN'} ==")
    print(f"  Mises à jour : {len(report['updated'])}")
    print(f"  Inchangées : {report['kept']}")
    if report['updated']:
        print('\nTransformations :')
        for doc_id, old, new in report['updated']:
            print(f"  '{old}' → '{new}'")

    if not apply_mode:
        print('\n→ Relancer avec --apply pour écrire.')


if __name__ == '__main__':
    main()
