import socket
# from threading import *
# #Dummy Reporting Server for testing
# serversocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
# host = "192.168.43.221"
# port = 6003
# serversocket.bind((host, port))

# class client(Thread):
#     def __init__(self, socket, address):
#         Thread.__init__(self)
#         self.sock = socket
#         self.addr = address
#         self.start()

#     def run(self):
#         while 1:
#             print(self.sock.recv(1024).decode())

# serversocket.listen(5)
# print ('reporting server started and listening')
# while 1:
#     clientsocket, address = serversocket.accept()
#     client(clientsocket, address)
#     print("connected")
print("started...")
def _recieve_configuration():
    socket_guest = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    socket_guest.bind(("192.168.43.221", 8989))
    socket_guest.listen(1)
    file = open('analysis.conf','wb')
    iteration_control = True
    while iteration_control:
        analyser, addr = socket_guest.accept()
        print("connected")
        data = analyser.recv(1024)
        while data:
            print("recieving...")
            file.write(data)
            data = analyser.recv(1024)
        file.close()
        analyser.close()
        iteration_control = False
    socket_guest.close()
    print("done")

_recieve_configuration()