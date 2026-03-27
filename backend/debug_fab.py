import httpx

c = httpx.Client(verify=False, base_url='https://127.0.0.1:8000')
html = c.get('/').text
print('fab-va in HTML:', 'fab-va' in html)
print('fab-va-popup in HTML:', 'fab-va-popup' in html)

js = c.get('/static/app.js', params={'v': '4'}).text
print('JS size:', len(js))
print('fabVaToggle:', 'function fabVaToggle' in js)
print('fabVaSend:', 'function fabVaSend' in js)
print('fabVaMic:', 'function fabVaMic' in js)

# Where is fab in relation to app-screen?
idx_fab = html.find('id="fab-va"')
idx_appscreen_close = html.find('</div><!-- #app-screen -->')
idx_auth = html.find('id="auth-screen"')
idx_appscreen_open = html.find('id="app-screen"')
print(f'app-screen opens at char {idx_appscreen_open}')
print(f'auth-screen at char {idx_auth}')
print(f'fab-va at char {idx_fab}')
print(f'app-screen closes at char {idx_appscreen_close}')
print(f'fab inside app-screen: {idx_appscreen_open < idx_fab < idx_appscreen_close}')

# Check if app-screen has display:none
lines = html.split('\n')
for i, l in enumerate(lines, 1):
    if 'app-screen' in l and 'id=' in l:
        print(f'app-screen line {i}: {l.strip()[:140]}')
    if 'auth-screen' in l and 'id=' in l:
        print(f'auth-screen line {i}: {l.strip()[:140]}')

# Check CSS for fab-va
css = c.get('/static/style.css', params={'v': '4'}).text
print('fab-va in CSS:', '.fab-va' in css)
print('fab-va position fixed:', 'position: fixed' in css and '.fab-va' in css)
