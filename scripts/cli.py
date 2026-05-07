#!/usr/bin/env python3
"""Универсальный CLI для Adstat (Magnetto Cabinet API).

Поддерживает любой эндпоинт через GET/POST/PUT/DELETE/PATCH.
Auto-refresh access токена при 401.

Usage:
  cli.py GET  /api/dashboard/balances
  cli.py GET  /api/v2/campaigns/ --param period=month --param limit=50
  cli.py POST /api/campaigns/ --body campaign.json
  cli.py PUT  /api/campaigns/123 --body-inline '{"name":"new"}'
"""
import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import urllib.error

ADSTAT_BASE = os.environ.get('ADSTAT_BASE', 'https://client.adstat.pro')
SKILL_DIR = os.environ.get(
    'ADSTAT_SKILL_DIR',
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)
TOKENS_FILE = os.path.expanduser('~/.claude/secrets/adstat-tokens')
ENV_FILE = os.path.join(SKILL_DIR, 'config', '.env')


def _load_kv(path):
    """Read simple KEY=VALUE file, ignore # comments."""
    data = {}
    if not os.path.exists(path):
        return data
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            k, v = line.split('=', 1)
            data[k.strip()] = v.strip()
    return data


def _save_tokens(access, refresh, user_id):
    now = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    payload = (
        f'# Adstat tokens (issued {now})\n'
        f'# access expires in 1h, refresh in 30d\n'
        f'ADSTAT_USER_ID={user_id}\n'
        f'ADSTAT_ACCESS_TOKEN={access}\n'
        f'ADSTAT_REFRESH_TOKEN={refresh}\n'
    )
    with open(TOKENS_FILE, 'w') as f:
        f.write(payload)
    os.chmod(TOKENS_FILE, 0o600)


def do_login():
    """Full login from .env → access+refresh."""
    env = _load_kv(ENV_FILE)
    login = env.get('ADSTAT_LOGIN')
    password = env.get('ADSTAT_PASSWORD')
    if not login or not password:
        sys.exit(f'ADSTAT_LOGIN/ADSTAT_PASSWORD не заполнены в {ENV_FILE}')

    body = urllib.parse.urlencode({'username': login, 'password': password}).encode()
    req = urllib.request.Request(
        f'{ADSTAT_BASE}/api/v2/login',
        data=body,
        method='POST',
        headers={'Content-Type': 'application/x-www-form-urlencoded'},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f'Login failed: HTTP {e.code} {e.read()[:200].decode("utf-8", "replace")}')
    if 'access_token' not in data:
        sys.exit(f'Login failed: {data}')
    _save_tokens(data['access_token'], data['refresh_token'], data['user_id'])
    return data


def do_refresh():
    """Refresh access via stored refresh."""
    tokens = _load_kv(TOKENS_FILE)
    refresh = tokens.get('ADSTAT_REFRESH_TOKEN')
    if not refresh:
        return None
    req = urllib.request.Request(
        f'{ADSTAT_BASE}/api/v2/access-token',
        method='GET',
        headers={'refresh_token': refresh},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.load(r)
    except urllib.error.HTTPError:
        return None
    if 'access_token' not in data:
        return None
    _save_tokens(data['access_token'], refresh, tokens.get('ADSTAT_USER_ID', ''))
    return data['access_token']


def get_access_token():
    tokens = _load_kv(TOKENS_FILE)
    if not tokens.get('ADSTAT_ACCESS_TOKEN'):
        do_login()
        tokens = _load_kv(TOKENS_FILE)
    return tokens['ADSTAT_ACCESS_TOKEN']


def api_request(method, path, params=None, body=None, retry_on_401=True):
    """Make API request, auto-refresh on 401, return parsed JSON or raw body."""
    access = get_access_token()
    url = ADSTAT_BASE + path
    if params:
        url += '?' + urllib.parse.urlencode(params, doseq=True)
    headers = {
        'Authorization': f'Bearer {access}',
        'Accept': 'application/json',
    }
    data = None
    if body is not None:
        if isinstance(body, (dict, list)):
            data = json.dumps(body).encode('utf-8')
            headers['Content-Type'] = 'application/json'
        else:
            data = body.encode('utf-8') if isinstance(body, str) else body
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            try:
                return json.loads(raw)
            except json.JSONDecodeError:
                return raw.decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        if e.code == 401 and retry_on_401:
            new_access = do_refresh()
            if new_access:
                return api_request(method, path, params, body, retry_on_401=False)
            else:
                sys.exit(
                    'Refresh не сработал — нужен re-login. '
                    f'Запусти: bash {SKILL_DIR}/scripts/auth-relogin.sh'
                )
        body_text = e.read().decode('utf-8', 'replace')
        try:
            return {'__http_error__': e.code, 'body': json.loads(body_text)}
        except json.JSONDecodeError:
            return {'__http_error__': e.code, 'body': body_text}


def parse_kv_list(items):
    out = {}
    for item in items or []:
        if '=' not in item:
            sys.exit(f'--param expects k=v, got: {item}')
        k, v = item.split('=', 1)
        out.setdefault(k, [])
        out[k].append(v) if isinstance(out[k], list) else None
        # Сделаем последнее значение основным; если множественные — uniq передаём списком
        out[k] = v if not isinstance(out.get(k), list) else out[k]
    # urllib.parse.urlencode хорошо работает со списками через doseq=True
    return out


def main():
    ap = argparse.ArgumentParser(description='Adstat (Magnetto) Cabinet API CLI')
    ap.add_argument('method', choices=['GET', 'POST', 'PUT', 'DELETE', 'PATCH'])
    ap.add_argument('path', help='e.g. /api/dashboard/balances')
    ap.add_argument('--param', action='append', default=[], help='Query param k=v')
    ap.add_argument('--body', help='Path to JSON file for body')
    ap.add_argument('--body-inline', help='Inline JSON string for body')
    ap.add_argument('--pretty', action='store_true', help='Pretty-print JSON')
    ap.add_argument('--raw', action='store_true', help='Print raw body, no JSON parse')
    args = ap.parse_args()

    params = parse_kv_list(args.param) if args.param else None
    body = None
    if args.body:
        with open(args.body) as f:
            body = json.load(f)
    elif args.body_inline:
        body = json.loads(args.body_inline)

    result = api_request(args.method, args.path, params=params, body=body)

    if args.raw:
        print(result if isinstance(result, str) else json.dumps(result, ensure_ascii=False))
    elif args.pretty:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
