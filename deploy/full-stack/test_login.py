#!/usr/bin/env python3
import urllib.request
import json

# The registered user has username "008613800138000" (zone+phone)
# Let's try login with different username formats

# Test login with full phone number (zone+phone)
data = json.dumps({
    "username": "008613800138000",
    "password": "test123456"
}).encode()
req = urllib.request.Request(
    'http://localhost:8090/v1/user/login',
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
try:
    resp = urllib.request.urlopen(req)
    print("Login with zone+phone Response:", resp.read().decode())
except urllib.error.HTTPError as e:
    print("Login with zone+phone Error:", e.read().decode())

# Test login with short_no
data2 = json.dumps({
    "username": "jqoOFC",
    "password": "test123456"
}).encode()
req2 = urllib.request.Request(
    'http://localhost:8090/v1/user/login',
    data=data2,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
try:
    resp2 = urllib.request.urlopen(req2)
    print("Login with short_no Response:", resp2.read().decode())
except urllib.error.HTTPError as e:
    print("Login with short_no Error:", e.read().decode())

# Test login with uid
data3 = json.dumps({
    "username": "2bce0b035c934eabb4a0843ad730ff6c",
    "password": "test123456"
}).encode()
req3 = urllib.request.Request(
    'http://localhost:8090/v1/user/login',
    data=data3,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
try:
    resp3 = urllib.request.urlopen(req3)
    print("Login with uid Response:", resp3.read().decode())
except urllib.error.HTTPError as e:
    print("Login with uid Error:", e.read().decode())
