# Scraper du catalogue pharmacie-ivoirienne.com via le Store API
# WooCommerce (wc/store/v1/products — endpoint PUBLIC utilisé par le front).
#
# Sortie : data/piv_products.json (liste de produits avec prix XOF)
# Usage : python scripts/scraper_piv.py [--max-pages N] [--out fichier.json]
import json
import sys
import time
import urllib.parse
import urllib.request

BASE = 'https://pharmacie-ivoirienne.com/wp-json/wc/store/v1/products'
UA = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
PER_PAGE = 100


def fetch_page(page: int):
    url = f'{BASE}?per_page={PER_PAGE}&page={page}'
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode('utf-8'))


def extract_price(product: dict):
    """Prix principal : regular_price si > 0, sinon prix des variations."""
    prices = product.get('prices', {})
    for key in ('regular_price', 'sale_price', 'price'):
        try:
            value = float(str(prices.get(key, '0')).replace(',', '.'))
        except (TypeError, ValueError):
            value = 0.0
        if value > 0:
            return value
    # Produits groupés/variables : prix des variations.
    variations = product.get('variations', [])
    if variations:
        values = []
        for v in variations:
            vp = v.get('prices', {})
            for key in ('regular_price', 'sale_price', 'price'):
                try:
                    value = float(str(vp.get(key, '0')).replace(',', '.'))
                except (TypeError, ValueError):
                    value = 0.0
                if value > 0:
                    values.append(value)
                    break
        if values:
            return min(values)
    return 0.0


def main():
    max_pages = None
    args = sys.argv[1:]
    if '--max-pages' in args:
        max_pages = int(args[args.index('--max-pages') + 1])

    products = []
    page = 1
    while True:
        if max_pages and page > max_pages:
            break
        try:
            batch = fetch_page(page)
        except urllib.error.HTTPError as e:
            print(f'Page {page} : HTTP {e.code} — fin (ou rate limit).')
            break
        except Exception as e:
            print(f'Page {page} : erreur {e} — pause puis reprise.')
            time.sleep(10)
            continue

        if not batch:
            print(f'Page {page} : vide — fin du catalogue.')
            break

        for p in batch:
            products.append({
                'source': 'pharmacie-ivoirienne.com',
                'name': p.get('name', ''),
                'slug': p.get('slug', ''),
                'price_xof': extract_price(p),
                'categories': [c.get('name', '') for c in p.get('categories', [])],
                'brands': [b.get('name', '') for b in p.get('brands', [])],
                'type': p.get('type', ''),
                'in_stock': p.get('is_in_stock', False),
                'url': p.get('permalink', ''),
            })

        print(f'Page {page} : {len(batch)} produits (total {len(products)})')
        if len(batch) < PER_PAGE:
            break
        page += 1
        time.sleep(0.8)  # politesse : ~1 requête/s

    out = 'data/piv_products.json'
    if '--out' in args:
        out = args[args.index('--out') + 1]
    import os
    os.makedirs('data', exist_ok=True)
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(products, f, ensure_ascii=False, indent=1)

    priced = [p for p in products if p['price_xof'] > 0]
    print(f'\n=== TERMINÉ : {len(products)} produits '
          f'({len(priced)} avec prix > 0) → {out}')


if __name__ == '__main__':
    main()
