import gcn
from datetime import datetime

def handler(payload, root):

    print("handling something")

    print(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    print("payload = %r" % payload)
    print("root    = %r" % root)
            
gcn.listen(host='voevent.svom.eu', port=8099, handler=handler, iamalive_timeout=100.0, max_reconnect_timeout=1)
