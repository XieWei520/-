#!/usr/bin/env python3
import urllib.request
import json

# Test 1: Send SMS code
data = json.dumps({"zone": "0086", "phone": "13800138000"}).encode()
req = urllib.request.Request(
    'http://localhost:8090/v1/user/sms/registercode',
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
try:
    resp = urllib.request.urlopen(req)
    print("SMS Code Response:", resp.read().decode())
except urllib.error.HTTPError as e:
    print("SMS Code Error:", e.read().decode())

# Test 2: Register user (after getting code)
data2 = json.dumps({
    "name": "TestUser",
    "zone": "0086",
    "phone": "13800138000",
    "code": "123456",
    "password": "test123456"
}).encode()
req2 = urllib.request.Request(
    'http://localhost:8090/v1/user/register',
    data=data2,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
try:
    resp2 = urllib.request.urlopen(req2)
    print("Register Response:", resp2.read().decode())
except urllib.error.HTTPError as e:
    print("Register Error:", e.read().decode())

# Test 3: Login
data3 = json.dumps({
    "username": "13800138000",
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
    print("Login Response:", resp3.read().decode())
except urllib.error.HTTPError as e:
    print("Login Error:", e.read().decode())
