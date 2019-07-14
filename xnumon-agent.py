from __future__ import print_function
import ConfigParser
import subprocess
import socket
import os
import signal
import sys
class Config:
    def __init__(self, cfg):
        config = ConfigParser.ConfigParser(allow_no_value=True)
        config.read(cfg)
        for section in config.sections():virtualbox
            for name, raw_value in config.items(section):
                if name == "file_name":
                    value = config.get(section, name)
                else:
                    try:
                        value = config.getboolean(section, name)
                    except ValueError:
                        try:
                            value = config.getint(section, name)
                        except ValueError:
                            value = config.get(section, name)
                setattr(self, name, value)

class Initiate_monitoring(object):
    def __init__(self):
        self.RECEIVING_PORT = 4343
        self.RECEIVING_HOST = "127.0.0.1"
        self.PID_PATH = '/private/var/run/xnumon.pid'
    def run(self):
        #kill if process is already running at receiving port
        self._kill_running(self.RECEIVING_PORT)
        #Get configurations
        self.CONFIGURATION_FILE = self._recieve_configuration()
        #Parse Configuration files
        self.config = Config(cfg=self.CONFIGURATION_FILE)
        #change working directory
        os.chdir("/usr/local/sbin/")
        #Initiate transmission
        self._transmit_log()
    #kill if any process is already running desired ports
    def _kill_running(self, port):
        process = subprocess.Popen(["lsof", "-i", ":{0}".format(port)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate()
        for process in str(stdout.decode("utf-8")).split("\n")[1:]:
            data = [x for x in process.split(" ") if x != '']
            if (len(data) <= 1):
                continue
            os.kill(int(data[1]), signal.SIGKILL)
        if os.path.isfile(self.PID_PATH):
            os.remove(self.PID_PATH)
    #Socket for receiving the analysis configuration files
    def _recieve_configuration(self):
        socket_guest = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        socket_guest.bind((self.RECEIVING_HOST, self.RECEIVING_PORT))
        socket_guest.listen(1)
        file = open('analysis.conf','wb')
        iteration_control = True
        while iteration_control:
            analyser, addr = socket_guest.accept()
            data = analyser.recv(1024)
            while data:
                file.write(data)
                data = analyser.recv(1024)
            file.close()
            analyser.close()
            iteration_control = False
        socket_guest.close()
        return "analysis.conf"
    #Reading stdout of subprocess per line
    def _execute(self,cmd):
        popen = subprocess.Popen(cmd, stdout=subprocess.PIPE, universal_newlines=True)
        for stdout_line in iter(popen.stdout.readline, ""):
            yield stdout_line
        popen.stdout.close()
        return_code = popen.wait()
        if return_code:
            raise subprocess.CalledProcessError(return_code, cmd)
    #Create host connection socket
    def _transmit_log(self):
        socket_host = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        socket_host.connect((self.config.ip, self.config.port))
        socket_host.connect("JSON\n")
        for logs in self._execute(["sudo", "./xnumon", "-d"]):
            try:
                socket_host.send(logs.encode());
            except KeyboardInterrupt:
                socket_host.shutdown(socket.SHUT_WR)
                socket_host.close()
#Main class
if __name__=="__main__":
    monitor = Initiate_monitoring()
    monitor.run()
