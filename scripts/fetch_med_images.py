# Pipeline d'images produits PharmaScan — ÉCHANTILLON (validation).
#
# Pour un échantillon de médicaments du seed :
#   1. Recherche web (Bing RSS, sans clé) : « <nom> boîte »
#   2. Télécharge les images candidates
#   3. Filtre (dimensions, contenu) + redimensionne 300x300 WebP
#   4. Sauvegarde en local (PAS d'upload tant que LEO n'a pas validé)
#
# Usage : python scripts/fetch_med_images.py [--limit N]
import io
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from html.parser import HTMLParser

from PIL import Image

UA = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

OUT_DIR = 'data/med_images_sample'


def bing_image_search(query: str, brand_hint: str, max_results: int = 10):
    """Recherche d'images via Bing (HTML, zéro clé) : URLs dans mediaurl.

    brand_hint : mot-clé (1er mot du nom, ex « doliprane ») qui DOIT
    apparaître dans l'URL — filtre les résultats hors-sujet (logos,
    tracteurs...).
    """
    url = ('https://www.bing.com/images/search?q='
           + urllib.parse.quote(query))
    req = urllib.request.Request(url, headers=UA)
    try:
        html = urllib.request.urlopen(req, timeout=20).read().decode('utf-8', errors='replace')
    except Exception as e:
        print(f'    recherche échouée : {e}')
        return []
    urls = re.findall(r'mediaurl=([^&"\']+)', html)
    hint = brand_hint.lower()
    seen = []
    for u in urls:
        u = urllib.parse.unquote(u)
        if not u.startswith('http'):
            continue
        if 'bing.com' in u or 'microsoft.com' in u:
            continue
        # Filtre de pertinence : le nom du médicament dans l'URL.
        if hint and hint not in u.lower():
            continue
        if u not in seen:
            seen.append(u)
        if len(seen) >= max_results:
            break
    return seen


def download(url: str, timeout: int = 15):
    req = urllib.request.Request(url, headers=UA)
    return urllib.request.urlopen(req, timeout=timeout).read()


def process_image(raw: bytes, code: str):
    """Valide + recadre carré + redimensionne 300x300 + WebP."""
    img = Image.open(io.BytesIO(raw)).convert('RGB')
    w, h = img.size
    if w < 150 or h < 150:
        return None  # trop petite : probablement un logo/pixel
    if w / h > 3 or h / w > 3:
        return None  # bannière, pas une boîte
    # Recadre carré centré
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    img = img.crop((left, top, left + side, top + side))
    img = img.resize((300, 300), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, 'WEBP', quality=70)
    return buf.getvalue()


def main():
    limit = 20
    if '--limit' in sys.argv:
        limit = int(sys.argv[sys.argv.index('--limit') + 1])

    data = json.load(open('data/medicament_prices_ci.json', encoding='utf-8'))
    # Marques courantes d'abord (validation plus parlante pour LEO),
    # DÉDUPLIQUÉES par marque (pas 12 variantes du même produit).
    known = ['DOLIPRANE', 'EFFERALGAN', 'PARACETAMOL', 'AMOXICILLINE',
             'IBUPROFENE', 'ASPIRINE', 'MAGNE B6', 'SPASFON', 'IMAZOLE',
             'GASTROPAC', 'DAFLON', 'TARDYFERON', 'SMECTA', 'GAVISCON',
             'VOLTARENE', 'BETADINE', 'CELESTENE', 'PENTAVIT', 'NIFLURIL',
             'XANAX']
    def rank(m):
        n = m['name'].upper()
        for i, k in enumerate(known):
            if k in n:
                return i
        return len(known)
    seen_brands = set()
    sample = []
    for m in sorted(data, key=rank):
        brand = m['name'].split(' ')[0].upper()
        if brand in seen_brands:
            continue
        seen_brands.add(brand)
        sample.append(m)
        if len(sample) >= limit:
            break

    os.makedirs(OUT_DIR, exist_ok=True)
    report = []

    for m in sample:
        name = m['name']
        code = m['code'] or re.sub(r'[^a-z0-9]+', '-', name.lower())[:20]
        brand = name.split(' ')[0].lower()
        # Requête SIMPLE : la marque + « boîte » (les noms complets avec
        # abréviations perdent Bing → résultats hors-sujet).
        query = f'{brand} boîte médicament'
        print(f'\n{name[:60]}')
        urls = bing_image_search(query, brand_hint='')
        saved = False
        for u in urls:
            try:
                raw = download(u)
                webp = process_image(raw, code)
                if webp is None:
                    continue
                path = os.path.join(OUT_DIR, f'{code}.webp')
                with open(path, 'wb') as f:
                    f.write(webp)
                print(f'  ✅ {u[:70]} → {len(webp)//1024} Ko')
                report.append({'code': code, 'name': name, 'source': u,
                               'file': path, 'size_kb': len(webp) // 1024})
                saved = True
                break
            except Exception:
                continue
        if not saved:
            print('  ❌ aucune image valide trouvée')

    with open(os.path.join(OUT_DIR, 'report.json'), 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
    print(f'\n=== {len(report)}/{len(sample)} images récupérées → {OUT_DIR}')


if __name__ == '__main__':
    main()
