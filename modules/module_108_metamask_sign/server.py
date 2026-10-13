import http.server,json,os,socketserver,sys
from urllib.parse import urlparse
R=os.path.dirname(os.path.abspath(__file__));E=sys.argv[1];P=int(sys.argv[2])
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(s,*a,**k):super().__init__(*a,directory=R,**k)
    def log_message(s,f,*a):sys.stderr.write("[srv] "+f%a+"\n")
    def do_POST(s):
        if urlparse(s.path).path!="/sign":s.send_error(404);return
        n=int(s.headers.get("Content-Length",0))
        try:d=json.loads(s.rfile.read(n))
        except Exception as e:s.send_error(400,str(e));return
        o=os.path.join(E,f"{d.get('cid','X')}_buyer.sig")
        open(o,"w").write(json.dumps(d,indent=2))
        open(o+".msg","w").write(d.get("message",""))
        s.send_response(200);s.send_header("Content-Type","application/json")
        s.end_headers();s.wfile.write(b'{"ok":true}')
socketserver.TCPServer.allow_reuse_address=True
with socketserver.TCPServer(("127.0.0.1",P),H) as x:x.serve_forever()
