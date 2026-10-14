"""Local camera receiver: python3 mac_camera.py."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Lock
import time
import secrets
from urllib.parse import urlsplit, parse_qs

TOKEN = secrets.token_urlsafe(24)

lock = Lock()
frame = b""
received = 0.0
PAGE = b'''<!doctype html><html><meta name="viewport" content="width=device-width">
<title>LEGO BOOST Camera</title><style>
body{margin:0;background:#101214;color:white;font:16px system-ui;text-align:center}
header{padding:16px;border-bottom:1px solid #333}img{max-width:100%;height:80vh;object-fit:contain}
</style><header>LEGO BOOST <span id="status">Waiting for iPhone</span></header>
<img id="camera" alt=""><script>
async function poll(){try{let r=await fetch('/frame',{cache:'no-store'});
if(r.ok){let u=URL.createObjectURL(await r.blob());let old=camera.src;camera.src=u;
if(old.startsWith('blob:'))URL.revokeObjectURL(old);statusText('Live');}
else statusText('Waiting for iPhone');}catch(e){statusText('Disconnected');}
setTimeout(poll,150)}
function statusText(s){document.getElementById('status').textContent=s}poll();
</script></html>'''

class Handler(BaseHTTPRequestHandler):
    def authorized(self):
        supplied = parse_qs(urlsplit(self.path).query).get('token', [''])[0]
        if secrets.compare_digest(supplied, TOKEN):
            return True
        self.send_error(403)
        return False

    def do_GET(self):
        if not self.authorized():
            return
        with lock:
            data = frame if time.monotonic() - received < 5 else b""
        if self.path.split('?')[0] == '/frame':
            self.send_response(200 if data else 503)
            self.send_header('Content-Type', 'image/jpeg')
        elif urlsplit(self.path).path == '/':
            data = PAGE.replace(b"fetch('/frame'", ("fetch('/frame?token=" + TOKEN + "'").encode())
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
        else:
            self.send_error(404)
            return
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        global frame, received
        if not self.authorized():
            return
        if urlsplit(self.path).path != '/frame':
            self.send_error(404)
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            self.send_error(400)
            return
        if not 0 < length <= 2_000_000:
            self.send_error(413)
            return
        self.connection.settimeout(5)
        data = self.rfile.read(length)
        if len(data) != length or not data.startswith(b'\xff\xd8'):
            self.send_error(400)
            return
        with lock:
            frame, received = data, time.monotonic()
        self.send_response(204)
        self.end_headers()

    def log_message(self, *args):
        pass

if __name__ == '__main__':
    print('Camera viewer: http://localhost:8765/?token=' + TOKEN, flush=True)
    ThreadingHTTPServer(('0.0.0.0', 8765), Handler).serve_forever()
