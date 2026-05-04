#!/usr/bin/env python3
import urllib.request, json

BASE = 'http://127.0.0.1:8090'

def req_post(path, data, token=None):
    body = json.dumps(data).encode()
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['token'] = token
    req = urllib.request.Request(f'{BASE}{path}', data=body, headers=headers, method='POST')
    return json.loads(urllib.request.urlopen(req, timeout=10).read().decode())

def req_get(path, token=None):
    headers = {}
    if token:
        headers['token'] = token
    req = urllib.request.Request(f'{BASE}{path}', headers=headers)
    return json.loads(urllib.request.urlopen(req, timeout=10).read().decode())

print('=== 1. Send SMS Code ===')
try:
    r = req_post('/v1/user/sms/registercode', {'zone': '0086', 'phone': '13800138002'})
    print('Result:', r)
except Exception as e:
    print('Error:', e)

print('\n=== 2. Register User ===')
try:
    r = req_post('/v1/user/usernameregister', {'name': 'TestUser3', 'zone': '0086', 'phone': '13800138002', 'code': '123456', 'password': 'test123456'})
    print('Result:', json.dumps(r, ensure_ascii=False))
    token = r.get('data', {}).get('token', '')
    uid = r.get('data', {}).get('uid', '')
    print(f'Token: {token[:30]}...' if token else 'No token')
    print(f'UID: {uid}')

    if token:
        print('\n=== 3. Get Current User ===')
        try:
            r = req_get('/v1/user/current', token)
            print('Current User:', json.dumps(r, ensure_ascii=False, indent=2))
        except Exception as e:
            print('Error:', e)

        print('\n=== 4. Favorites API ===')
        try:
            r = req_get('/v1/favorites', token)
            print('Favorites:', json.dumps(r, ensure_ascii=False))
        except Exception as e:
            print('Error:', e)

        print('\n=== 5. Tags API ===')
        try:
            r = req_get('/v1/tags', token)
            print('Tags:', json.dumps(r, ensure_ascii=False))
        except Exception as e:
            print('Error:', e)

        print('\n=== 6. Create Tag ===')
        try:
            r = req_post('/v1/tag', {'name': '同事', 'remark': '工作同事'}, token)
            print('Create Tag:', json.dumps(r, ensure_ascii=False))
        except Exception as e:
            print('Error:', e)

        print('\n=== 7. Moments API ===')
        try:
            r = req_get('/v1/moments', token)
            print('Moments:', json.dumps(r, ensure_ascii=False))
        except Exception as e:
            print('Error:', e)

        print('\n=== 8. User Settings ===')
        try:
            r = req_get('/v1/user/setting', token)
            print('Settings:', json.dumps(r, ensure_ascii=False))
        except Exception as e:
            print('Error:', e)

        print('\n=== 9. Friends API ===')
        try:
            r = req_get('/v1/friends', token)
            print('Friends:', json.dumps(r, ensure_ascii=False))
        except Exception as e:
            print('Error:', e)

        print('\n=== 10. Blacklist API ===')
        try:
            r = req_get('/v1/user/blacklists', token)
            print('Blacklist:', json.dumps(r, ensure_ascii=False))
        except Exception as e:
            print('Error:', e)

except Exception as e:
    print('Register Error:', e)

print('\n=== All API Tests Complete ===')
