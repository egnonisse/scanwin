# Crée l'index composite Firestore priceEntries(medicationName ASC, price ASC)
# requis par la recherche de prix (où + ordre sur 2 champs).
import base64
import json
import time
import urllib.parse
import urllib.request
import urllib.error

KEY = json.load(open(r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json', encoding='utf-8'))
PROJECT = 'boostsocial-a7720'


def access_token() -> str:
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import padding

    now = int(time.time())
    header = {'alg': 'RS256', 'typ': 'JWT', 'kid': KEY['private_key_id']}
    payload = {
        'iss': KEY['client_email'],
        'scope': 'https://www.googleapis.com/auth/cloud-platform',
        'aud': 'https://oauth2.googleapis.com/token',
        'iat': now,
        'exp': now + 3600,
    }

    def b64(obj):
        return base64.urlsafe_b64encode(json.dumps(obj).encode()).rstrip(b'=')

    signing = b64(header) + b'.' + b64(payload)
    key = serialization.load_pem_private_key(KEY['private_key'].encode(), password=None)
    sig = key.sign(signing, padding.PKCS1v15(), hashes.SHA256())
    jwt = signing + b'.' + base64.urlsafe_b64encode(sig).rstrip(b'=')
    req = urllib.request.Request(
        'https://oauth2.googleapis.com/token',
        data=urllib.parse.urlencode({
            'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion': jwt.decode(),
        }).encode(),
        headers={'Content-Type': 'application/x-www-form-urlencoded'},
    )
    return json.loads(urllib.request.urlopen(req, timeout=30).read())['access_token']


def main():
    token = access_token()
    base = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)'

    # 1. Vérifier si l'index existe déjà
    req = urllib.request.Request(
        f'{base}/collectionGroups/priceEntries/indexes',
        headers={'Authorization': f'Bearer {token}'},
    )
    existing = json.loads(urllib.request.urlopen(req, timeout=60).read())
    for idx in existing.get('indexes', []):
        fields = [(f.get('fieldPath'), f.get('order')) for f in idx.get('fields', [])]
        if fields == [('medicationName', 'ASCENDING'), ('price', 'ASCENDING')]:
            print(f"✅ Index EXISTE DÉJÀ : {idx.get('state')} ({idx.get('name')})")
            return

    # 2. Le créer
    body = {
        'queryScope': 'COLLECTION_GROUP',
        'fields': [
            {'fieldPath': 'medicationName', 'order': 'ASCENDING'},
            {'fieldPath': 'price', 'order': 'ASCENDING'},
        ],
    }
    req = urllib.request.Request(
        f'{base}/collectionGroups/priceEntries/indexes',
        method='POST',
        data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
    )
    try:
        resp = json.loads(urllib.request.urlopen(req, timeout=60).read())
        print(f"✅ Index CRÉÉ : {resp.get('state')} — attendre CREATING→READY")
        print(f"   name: {resp.get('name')}")
    except urllib.error.HTTPError as e:
        print('Erreur:', e.code, e.read().decode()[:400])


if __name__ == '__main__':
    main()
