from __future__ import print_function
import subprocess
import socket
import os
import sys

#check if an instance of xnumon is already running.
#If yes, terminate it, and restart with the script.
#To check, monitor the xnumon.pid file
PID_PATH = '/private/var/run/xnumon.pid'
if os.path.isfile(PID_PATH):
    os.remove(PID_PATH)

#change to xnumon working directory
os.chdir("/usr/local/sbin/")

#initiate a socket connection to the reporting server
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
host ="127.0.0.1"
port = int(sys.argv[1])
s.connect((host,port))

#function for per line identification of standard out
def execute(cmd):
    popen = subprocess.Popen(cmd, stdout=subprocess.PIPE, universal_newlines=True)
    for stdout_line in iter(popen.stdout.readline, ""):
        yield stdout_line 
    popen.stdout.close()
    return_code = popen.wait()
    if return_code:
        raise subprocess.CalledProcessError(return_code, cmd)

#transmitting system log events through sockets
for logs in execute(["./xnumon", "-d"]):
     s.send(logs.encode());
