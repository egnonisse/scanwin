# Parse la liste des prix de médicaments de pharmacies-de-garde.ci
# (3 874 références : code, nom, groupe thérapeutique, prix public FCFA).
# Sortie : data/medicament_prices_ci.json
import html
import json
import re
import sys

PATH = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\LEO\AppData\Local\Temp\pdg.html'

raw = open(PATH, encoding='utf-8').read()

table = re.search(r'<table.*?</table>', raw, re.DOTALL)
if not table:
    print('Aucun tableau trouvé')
    sys.exit(1)

rows = re.findall(r'<tr.*?</tr>', table.group(0), re.DOTALL)
print(f'{len(rows)} lignes trouvées (en-tête inclus)')

medicaments = []
for row in rows[1:]:
    cells = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.DOTALL)
    if len(cells) < 5:
        continue

    def clean(cell):
        return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', '', cell))).strip()

    numero = clean(cells[0])
    code = clean(cells[1])
    nom = clean(cells[2])
    groupe = clean(cells[3])
    prix_raw = clean(cells[4])

    # Prix : « 1 240 » ou « 2 095,50 » → nombre
    prix_clean = re.sub(r'[\s\u00a0]', '', prix_raw).replace(',', '.')
    try:
        prix = float(prix_clean)
    except ValueError:
        continue

    if not nom or prix <= 0:
        continue

    medicaments.append({
        'numero': numero,
        'code': code,
        'name': nom,
        'therapeutic_group': groupe,
        'price_xof': prix,
        'source': 'pharmacies-de-garde.ci (prix publics CI)',
    })

# Dédupliquer par (nom, prix)
seen = set()
unique = []
for m in medicaments:
    key = (m['name'].upper(), m['price_xof'])
    if key not in seen:
        seen.add(key)
        unique.append(m)

out = 'data/medicament_prices_ci.json'
import os
os.makedirs('data', exist_ok=True)
with open(out, 'w', encoding='utf-8') as f:
    json.dump(unique, f, ensure_ascii=False, indent=1)

print(f'{len(unique)} médicaments avec prix → {out}')
print('\nExemples :')
for m in sorted(unique, key=lambda x: x['name'])[:8]:
    print(f"  {m['name'][:45]:47s} {m['price_xof']:>9,.0f} FCFA | {m['therapeutic_group'][:35]}")
for m in unique:
    if 'DOLIPRANE' in m['name'].upper()[:20]:
        print(f"  DOLIPRANE → {m['name']}: {m['price_xof']:,.0f} FCFA")
