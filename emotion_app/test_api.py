import urllib.request
import json
import random

base_url = 'https://emotion-detection.runasp.net/api'

def req(path, data=None, token=None):
    url = f"{base_url}{path}"
    req_obj = urllib.request.Request(url, method='POST' if data else 'GET')
    req_obj.add_header('Content-Type', 'application/json')
    if token:
        req_obj.add_header('Authorization', f'Bearer {token}')
    if data:
        req_obj.data = json.dumps(data).encode('utf-8')
    try:
        with urllib.request.urlopen(req_obj) as response:
            return response.status, response.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI5NWM0ODBmYS1hNzBlLTQ2MDYtYTVhNS00MTUzOWUxOTM5NzYiLCJlbWFpbCI6InRlc3RfMzg1NUBleGFtcGxlLmNvbSIsImp0aSI6IjkzZDdlYmY4LTczNTctNGUyMy1iMTY3LTFiZmMxMDJlYzQ5NyIsImh0dHA6Ly9zY2hlbWFzLnhtbHNvYXAub3JnL3dzLzIwMDUvMDUvaWRlbnRpdHkvY2xhaW1zL25hbWVpZGVudGlmaWVyIjoiOTVjNDgwZmEtYTcwZS00NjA2LWE1YTUtNDE1MzllMTkzOTc2IiwiZnVsbE5hbWUiOiJUZXN0IFVzZXIiLCJpc0FjdGl2ZSI6IlRydWUiLCJodHRwOi8vc2NoZW1hcy5taWNyb3NvZnQuY29tL3dzLzIwMDgvMDYvaWRlbnRpdHkvY2xhaW1zL3JvbGUiOiJVU0VSIiwiZXhwIjoxNzc3MzI3NzE0LCJpc3MiOiJNeUFwcCIsImF1ZCI6Ik15QXBwVXNlcnMifQ.nOQrdsJcYeNC_wPZ4LABL_UD4IW8ekQpA53er3eqsI8"

# 3. Analyze text
print("Analyzing text...")
status, body = req('/analysis/text', {
    "client_id": f"test_client_{random.randint(1000,9999)}",
    "result": {
        "text": "I am so incredibly happy today!"
    }
}, token)
print("Analyze:", status, body)
