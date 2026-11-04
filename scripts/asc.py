"""Minimal App Store Connect API client for the Drawspeak TestFlight pipeline.

Usage: asc.py GET <path>
       asc.py POST|PATCH <path> <json-body>   (allow-listed paths only)

Run: uv run -q --with pyjwt --with cryptography python -I scripts/asc.py GET /v1/apps/6830611699

The private key is read from ~/.appstoreconnect/private_keys and never printed
or copied. GET is unrestricted; writes are limited to the allow-list below.
Exit codes: 0 ok, 1 HTTP error, 2 HTTP 409 (conflict / already exists).
"""
import json
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

import jwt

KEY_ID = '2PX9L952HH'
ISSUER = '21e40dd1-5b96-4c70-a35e-f5b49ba22361'
ID = r'[0-9A-Za-z-]{6,64}'
WRITES = {
    # Export compliance: app encryption declaration and its link to one build.
    ('POST', r'/v1/appEncryptionDeclarations'),
    ('POST', rf'/v1/appEncryptionDeclarations/{ID}/relationships/builds'),
    ('PATCH', rf'/v1/builds/{ID}/relationships/appEncryptionDeclaration'),
    # Add one build to a beta group (only for a group without access to all builds).
    ('POST', rf'/v1/betaGroups/{ID}/relationships/builds'),
    # IOS_APP_STORE provisioning profile for manual distribution signing.
    ('POST', r'/v1/profiles'),
    # Internal beta group and its testers.
    ('POST', r'/v1/betaGroups'),
    ('POST', rf'/v1/betaGroups/{ID}/relationships/betaTesters'),
    ('POST', r'/v1/betaTesters'),
}

args = sys.argv[1:]
if len(args) < 2:
    raise SystemExit('Usage: asc.py GET <path> | asc.py POST|PATCH <path> <json>')
method, path = args[0], args[1]
if not path.startswith('/v1/'):
    raise SystemExit('Expected an ASC /v1/ path')
if method == 'GET':
    if len(args) != 2:
        raise SystemExit('GET takes no body')
    body = None
elif method in ('POST', 'PATCH'):
    if len(args) != 3:
        raise SystemExit(method + ' needs a JSON body')
    bare = path.split('?', 1)[0]
    if bare != path or not any(m == method and re.fullmatch(p, bare) for m, p in WRITES):
        raise SystemExit('Write not allow-listed: ' + method + ' ' + path)
    body = json.dumps(json.loads(args[2])).encode()
else:
    raise SystemExit('Unsupported method ' + method)

key_path = pathlib.Path.home() / '.appstoreconnect/private_keys' / ('AuthKey_' + KEY_ID + '.p8')
now = int(time.time())
token = jwt.encode({'iss': ISSUER, 'iat': now - 10, 'exp': now + 900, 'aud': 'appstoreconnect-v1'},
                   key_path.read_bytes(), algorithm='ES256', headers={'kid': KEY_ID, 'typ': 'JWT'})
req = urllib.request.Request('https://api.appstoreconnect.apple.com' + path, data=body, method=method,
                             headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
try:
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
        print(data.decode() if data else '{}')
except urllib.error.HTTPError as e:
    print('ASC HTTP ' + str(e.code) + ': ' + e.read().decode(), file=sys.stderr)
    sys.exit(2 if e.code == 409 else 1)
