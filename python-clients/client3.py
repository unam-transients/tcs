import socket
import json
import sys
import os
import re
from datetime import datetime


def Whitoutcomment(f):
    data = f.read(-1)
    r = re.compile("^[ ƒ\t]*//.*$", re.MULTILINE)
    data = re.sub(r, "", data)
    return data


sending_msg = b""

if os.path.exists("$TCSPREFIX"):
    with open("$TCSPREFIX/etc/tcs/servers.json") as f:
        data = json.loads(Whitoutcomment(f))
        print("1")
else:
    try:
        with open("/usr/local/etc/tcs/servers.json") as f:
            data = json.loads(Whitoutcomment(f))
            print("3")
    except:
        try:
            with open("servers.json") as f:
                data = json.loads(Whitoutcomment(f))
                print("4")

        except:
            print("servers.json cant be find")
            sys.exit(0)


request = sys.argv
params = []

if request[1] != "request":
    print("this is not a request")
    sys.exit(0)

port = int(data[request[2]]["port"])
host = str(data[request[2]]["host"])
print("port : {}".format(port))
print("host : {}".format(host))
method = request[3]
o = 0
if port == 5000:
    method = ""
    if request[3] != "log":
        o = 1
if len(request) >= 4 - o:
    for i in range(4 - o, len(request)):
        params += [request[i]]

Id = ""
timestamp = datetime.now().isoformat()
if method == "":

    if len(params) == 3:
        params += [request[-1]]
    params[2] = timestamp

    payload = {
        "method": "log",
        "params": {
            "who": params[0],
            "type": params[1],
            "timestamp": params[2],
            "payload": params[3],
        },
        "jsonrpc": "2.0",
    }

else:
    payload = {"method": method, "params": params, "jsonrpc": "2.0", "id": Id}

print(payload)
payload = json.dumps(payload)  # transfrom dict in string
payload += "\n"
sending_msg = payload.encode()

try:

    server_conexion = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_conexion.connect((host, port))
    print("Connexion established with {}".format(port))
    server_conexion.send(sending_msg)
    print("send")
    if method != "":
        msg_received = server_conexion.recv(2048)
        msg = msg_received.decode()
        a = msg.find("{", 5)
        b = msg[:a]
        msg = msg.replace(b, "")
        msg = msg.replace("{", "")
        msg = msg.replace("{", "")
        msg = msg.replace("}", "")
        msg = msg.replace("'", "")
        msg = msg.replace('"', "")
        msg = msg.split(",")
        for i in range(len(msg)):
            msg2 = msg[i].split(":")
            print(msg2[0], ":", end="")
            a = len(msg2[0])
            a = 32 - a
            for j in range(a):
                print(" ", end="")
            print(msg2[1])


except:
    print("You have been kicked or a crash ocured")

print("close")
server_conexion.close()
