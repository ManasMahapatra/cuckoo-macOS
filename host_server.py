import socket
from threading import *
#Dummy Reporting Server for testing
serversocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
host = "192.168.43.221"
port = 6003
serversocket.bind((host, port))

class client(Thread):
    def __init__(self, socket, address):
        Thread.__init__(self)
        self.sock = socket
        self.addr = address
        self.start()

    def run(self):
        while 1:
            print(self.sock.recv(1024).decode())

serversocket.listen(5)
print ('reporting server started and listening')
while 1:
    clientsocket, address = serversocket.accept()
    client(clientsocket, address)
    print("connected")
