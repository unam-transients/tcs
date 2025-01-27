import socket
import json
import sys
import os
import re
from datetime import datetime


def removelinecomments(s):
    r = re.compile("^[ \t]*//.*$", re.MULTILINE)
    return re.sub(r, "", s)


def serversfilename():
    if "TCSPREFIX" in os.environ:
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

if len(sys.argv) < 3:
    print("usage error: " + sys.argv[0] + " server method [param ...]")
    sys.exit(1)

server = sys.argv[1]
method = sys.argv[2]
if len(sys.argv) == 2:
    params = []
else:
    params = sys.argv[3:]
id = datetime.now().isoformat()
request = {"method": method, "params": params, "jsonrpc": "2.0", "id": id}
requeststring = json.dumps(request) + "\n"
requeststring = requeststring.encode(encoding="UTF-8", errors="strict")

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

try:
    with s.makefile("r") as f:
        responsestring = f.readline()
    response = json.loads(responsestring)
    s.close()
except:
    print("error while receiving response")
    sys.exit(1)

if not "jsonrpc" in response or response["jsonrpc"] != "2.0":
    print("invalid response: jsonrpc member is invalid")
    sys.exit(1)
elif not "id" in response or response["id"] != id:
    print("invalid response: id does not match")
    sys.exit(1)
elif "error" in response:
    print("error response: " + response["error"]["message"])
    sys.exit(1)
elif "result" in response:
    for key in response["result"]:
        print(key + " = " + response["result"][key])
else:
    print("invalid response")
    sys.exit(1)

sys.exit(0)
