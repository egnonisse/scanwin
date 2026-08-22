# Scraper référentiel médicaments — Base de Données Publique des Médicaments (ANSM)
# Fusionne CIS_bdpm (noms/forme/statut) + CIS_COMPO (substances actives DCI)
# et importe dans Firestore (collection medications).
import argparse
import codecs
import os
import time
import urllib.request
from collections import defaultdict

UA = {'User-Agent': 'PharmaScan/1.0 (referential import; contact: tobossinonleonard@gmail.com)'}
BASE = 'https://base-donnees-publique.medicaments.gouv.fr/download/file'

FILES = {
    'cis': f'{BASE}/CIS_bdpm.txt',
    'compo': f'{BASE}/CIS_COMPO_bdpm.txt',
}


def download(name: str, out_dir: str) -> str:
    out = os.path.join(out_dir, f'{name}.txt')
    if os.path.exists(out) and os.path.getsize(out) > 100_000:
        print(f'  {name}: déjà téléchargé ({os.path.getsize(out)} octets)')
        return out
    req = urllib.request.Request(FILES[name], headers=UA)
    data = urllib.request.urlopen(req, timeout=600).read()
    open(out, 'wb').write(data)
    print(f'  {name}: téléchargé ({len(data)} octets)')
    return out


def parse_cis(path: str) -> dict:
    """CIS → {name, form, routes, status, dcis: set}"""
    meds = {}
    with codecs.open(path, 'r', 'latin-1') as f:
        for line in f:
            fields = line.rstrip('\n').split('\t')
            if len(fields) < 8:
                continue
            cis = fields[0].strip()
            name = fields[1].strip()
            form = fields[2].strip()
            routes = fields[3].strip()
            status = fields[6].strip()
            if not cis or not name:
                continue
            meds[cis] = {
                'name': name,
                'form': form,
                'routes': routes,
                'status': status,
                'dcis': set(),
            }
    return meds


def parse_compo(path: str, meds: dict):
    with codecs.open(path, 'r', 'latin-1') as f:
        for line in f:
            fields = line.rstrip('\n').split('\t')
            if len(fields) < 4:
                continue
            cis = fields[0].strip()
            substance = fields[3].strip()
            if cis in meds and substance:
                meds[cis]['dcis'].add(substance)


def to_firestore_docs(meds: dict, commercialised_only: bool) -> list[dict]:
    docs = []
    for cis, m in meds.items():
        if commercialised_only and m['status'] != 'Commercialisée':
            continue
        docs.append({
            'cis': cis,
            'name': m['name'],
            'form': m['form'],
            'routes': m['routes'],
            'dcis': sorted(m['dcis']),
            'status': m['status'],
            'source': 'ansm_bdpm',
        })
    return docs


def sync_firestore(docs: list[dict], sa_key: str, dry_run: bool) -> dict:
    from firebase_admin import credentials, firestore, initialize_app
    import firebase_admin

    if not firebase_admin._apps:
        initialize_app(credentials.Certificate(sa_key))
    db = firestore.client()

    print(f'\n[dry-run]' if dry_run else '\n[IMPORT]', end=' ')
    print(f'{len(docs)} médicaments → Firestore (collection medications)')

    if dry_run:
        # Aperçu de 5 docs
        for d in docs[:5]:
            print(f'  • {d["name"][:55]:55s} | {", ".join(d["dcis"])[:40]}')
        return {'dry_run': len(docs)}

    batch = db.batch()
    count = 0
    imported = 0
    for d in docs:
        batch.set(db.collection('medications').document(), d)
        count += 1
        imported += 1
        if count >= 400:
            batch.commit()
            batch = db.batch()
            count = 0
            print(f'  ... {imported} importés')
    if count > 0:
        batch.commit()
    return {'imported': imported}


def main():
    ap = argparse.ArgumentParser(description='Scraper référentiel médicaments ANSM → Firestore')
    ap.add_argument('--out-dir', default=r'C:\Users\LEO\projects\pharmascan\play\medicaments')
    ap.add_argument('--sa-key', default=r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json')
    ap.add_argument('--all', action='store_true',
                    help='Importer TOUS les médicaments (pas seulement les commercialisés)')
    ap.add_argument('--dry-run', action='store_true',
                    help='Aperçu sans écriture Firestore')
    args = ap.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)

    print('[1/4] Téléchargement des fichiers officiels ANSM...')
    cis_path = download('cis', args.out_dir)
    compo_path = download('compo', args.out_dir)

    print('[2/4] Parsing...')
    meds = parse_cis(cis_path)
    print(f'  {len(meds)} médicaments uniques (CIS)')
    parse_compo(compo_path, meds)
    with_dci = sum(1 for m in meds.values() if m['dcis'])
    print(f'  {with_dci} avec au moins une substance active (DCI)')

    print('[3/4] Filtrage...')
    docs = to_firestore_docs(meds, commercialised_only=not args.all)
    print(f'  {len(docs)} médicaments retenus ({"commercialisés seulement" if not args.all else "tous"})')

    print('[4/4] Import Firestore...')
    result = sync_firestore(docs, args.sa_key, args.dry_run)
    print('Résultat:', result)


if __name__ == '__main__':
    main()
