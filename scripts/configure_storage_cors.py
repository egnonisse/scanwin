# Configure le CORS du bucket Firebase Storage (requis pour l'upload
# depuis Flutter WEB — le dashboard).
import base64
import json
import time
import urllib.parse
import urllib.request
import urllib.error

import firebase_admin
from firebase_admin import credentials

SA_KEY = r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json'
KEY = json.load(open(SA_KEY, encoding='utf-8'))
BUCKET = 'boostsocial-a7720.firebasestorage.app'


def access_token() -> str:
    import cryptography
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import padding

    now = int(time.time())
    header = {'alg': 'RS256', 'typ': 'JWT', 'kid': KEY['private_key_id']}
    payload = {
        'iss': KEY['client_email'],
        'scope': 'https://www.googleapis.com/auth/devstorage.full_control',
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
    cors = [
        {
            'origin': [
                'https://boostsocial-a7720.web.app',
                'https://boostsocial-a7720.firebaseapp.com',
                'http://localhost:8080',
                'http://localhost:3000',
            ],
            'method': ['GET', 'PUT', 'POST', 'DELETE', 'HEAD', 'OPTIONS'],
            'maxAgeSeconds': 3600,
            'responseHeader': [
                'Content-Type',
                'Content-Length',
                'x-goog-meta-*',
                'Authorization',
            ],
        }
    ]

    token = access_token()
    url = f'https://storage.googleapis.com/storage/v1/b/{BUCKET}'
    req = urllib.request.Request(
        url,
        method='PATCH',
        data=json.dumps({'cors': cors}).encode(),
        headers={
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
        },
    )
    try:
        resp = json.loads(urllib.request.urlopen(req, timeout=60).read())
        print('CORS configuré sur le bucket ✅')
        print(json.dumps(resp.get('cors'), indent=1))
    except urllib.error.HTTPError as e:
        print('Erreur HTTP', e.code, e.read().decode()[:400])


if __name__ == '__main__':
    main()
