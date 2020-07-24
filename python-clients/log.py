import socket
import json
import sys 
import os
import re
from datetime import datetime

def removelinecomments(s): 
        r = re.compile('^[ \t]*//.*$',re.MULTILINE)
        return re.sub(r, '', s)

def serversfilename():
        if "tcsprefix" in os.environ:
                return os.environ["TCSPREFIX"] + "/etc/tcs/servers.json"
        else:
                return "/usr/local/etc/tcs/servers.json"
                
def readserversfile():
        filename = serversfilename()
        if not os.path.exists(filename):
                print("servers file does not exist: " + filename)
                sys.exit(1)
        try:
                with open(filename) as f:
                        s = f.read(-1)
                        data = json.loads(removelinecomments(s))
                        return data
        except:
                print("servers file cannot be opened: " + filename)
                sys.exit(1)
                
def serverhost(serversdata, server):
        try:
                return str(serversdata[server]["host"])
        except:
                print("invalid server: " + server)
                sys.exit(1)

def serverport(serversdata, server):
        try:
                return int(serversdata[server]["port"])
        except:
                print("invalid server: " + server)
                sys.exit(1)

################################################################################

if len(sys.argv) != 4:
        print("usage error: " + sys.argv[0] + " who type payload")
        sys.exit(1)

server = "log"
who = sys.argv[1]
type = sys.argv[2]
payload = str(sys.argv[3])
timestamp = datetime.now().isoformat()
request = {
        "method": "log",
        "params": {
                "who" : who,
                "type" : type,
                "payload" : payload,
                "timestamp" : timestamp
        },
        "jsonrpc": "2.0",
}

requeststring = json.dumps(request) + "\n"
requeststring = requeststring.encode(encoding='UTF-8',errors='strict')
                
serversdata = readserversfile()
host = serverhost(serversdata, server)
port = serverport(serversdata, server)

try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((host, port))
        s.sendall(requeststring)
except:
        print("error while sending request")
        sys.exit(1)
        
sys.exit(0)
