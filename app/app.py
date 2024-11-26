import json
import os
import psutil
import socket
import subprocess
import sys
from flask import Flask, send_file, jsonify, request

app = Flask(__name__)

vmlist = {}


def get_vmlist():
    vmlist.clear()
    for filename in os.listdir('etc'):
        if filename.endswith('.conf'):
            vmname = None
            config_data = {}
            with open(f'etc/{filename}', 'r') as f:
                lines = f.readlines()
                for line in lines:
                    line = line.strip()
                    if not line:
                        continue
                    elif line.startswith('vm='):
                        vmname = line.split('=')[1].strip()
                        continue
                    elif line.startswith('#') or line.startswith('extra'):
                        continue
                    elif '=' in line:
                        key, value = line.split('=', 1)
                        config_data[key.strip()] = value.strip()
            
            if vmname is None:
                sys.exit(f"no vm field in {filename}")
            
            # Check if QEMU process is running 
            pid_file = f'qemu-{vmname}.pid'
            status = 'running' if os.path.exists(pid_file) else 'stopped'

            vmlist[vmname] = config_data
            vmlist[vmname]['status'] = status

    return vmlist


def list_files(path):
    try:
        items = os.listdir(path)
        return jsonify(items)
    except FileNotFoundError:
        return jsonify({"error": "Directory not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500


def get_port(vmname, service, default_port):
    port = default_port
    if service in vmlist[vmname]:
        return vmlist[vmname][service]
    for vm in vmlist:
        if not service in vmlist[vm]:
            continue
        vm_port = int(vmlist[vm][service])
        if vm_port >= port:
            port = vm_port + 1

    return port


def query_qmp(command, vmname):
    if not 'qmp_port' in vmlist[vmname]:
        return jsonify(
            {"success": False, "message": f"QMP not enabled in {vmname}"}
        ), 404

    qmp_port = int(vmlist[vmname]['qmp_port'])

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        rep_len = 8192
        s.connect(("localhost", qmp_port))
        response = s.recv(rep_len)
        # mandatory before command (duh?)
        s.sendall('{"execute": "qmp_capabilities"}\n'.encode('utf-8'))
        response = s.recv(rep_len)
        # actual command
        s.sendall(f'{{"execute": "{command}"}}\n'.encode('utf-8'))
        response = s.recv(rep_len)

        return json.loads(response)


def get_cpu_usage(vmname):
    cpu_percent = 0.0
    # read TID from QMP
    r = query_qmp("query-cpus-fast", vmname)
    for cpu in r['return']:
        with open(f"qemu-{vmname}.pid", "r") as f:
            pid = int(f.read().strip())
            process = psutil.Process(pid)
            for thread in process.threads():
                if thread.id == cpu['thread-id']:
                    cpu_percent += process.cpu_percent()

    return cpu_percent / len(r)

## routes

@app.route("/")
def index():
    # do not render template, frontend logic handled by Vue
    return send_file("index.html")


@app.route("/vmlist")
def vm_list():
    return jsonify(get_vmlist())


@app.route("/getkernels")
def getkernels():
    return list_files("kernels")


@app.route("/getimages")
def getimages():
    return list_files("images")


@app.route("/start", methods=["POST"])
def start_vm():
    vm_name = request.json.get("vm_name")

    config_file = f'etc/{vm_name}.conf'

    if not os.path.exists(config_file):
        return jsonify(
            {"success": False, "message": "Config file not found"}
        ), 404

    try:
        subprocess.Popen(["./startnb.sh", "-f", config_file, "-d"])
        return jsonify({"success": True, "message": "Starting VM"})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/stop", methods=["POST"])
def stop_vm():
    vm_name = request.json.get("vm_name")

    pid_file = f'qemu-{vm_name}.pid'

    if not os.path.exists(pid_file):
        return jsonify(
            {"success": False, "message": "PID file not found"}
        ), 404

    try:
        with open(pid_file, 'r') as f:
            pid = f.read().strip()
        os.kill(int(pid), 15)
        return jsonify({"success": True, "message": "Stopping VM"})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/saveconf", methods=['POST'])
def saveconf():
    try:
        data = request.get_json()
        if not data:
            return jsonify(
                {"success": False, "message": "No JSON payload provided"}
            ), 400

        vmname = data.get("vm")
        if not vmname:
            return jsonify(
                {
                    "success": False,
                    "message": "'vm' key is required in the JSON payload"
                }
            ), 400

        directory = './etc'
        os.makedirs(directory, exist_ok=True)
        file_path = os.path.join(directory, f"{vmname}.conf")

        with open(file_path, 'w') as file:
            for key, value in data.items():
                if key == "tcpserial":
                    if value is True:
                        serial_port = get_port(vmname, 'serial_port', 5555)
                        key = "serial_port"
                        value = f"{serial_port}"
                    else:
                        continue
                file.write(f"{key}={value}\n")

            qmp_port = get_port(vmname, 'qmp_port', 4444)
            file.write(f'qmp_port={qmp_port}\n')
            extra = 'extra="-pidfile qemu-${vm}.pid"'
            file.write(f'{extra}\n')

        return jsonify({"success": True, "message": file_path}), 200

    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route('/rm/<vm>', methods=['DELETE'])
def rm_file(vm):
    try:
        filepath = f"etc/{vm}.conf"

        if not os.path.isfile(filepath):
            return jsonify(
                {"success": False, "message": f"'{vm}' not found"}
            ), 404

        os.remove(filepath)
        return jsonify(
            {"success": True, "message": f"'{vm}' deleted successfully"}
        ), 200

    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route('/qmp/<vmname>/<command>')
def qmp(vmname, command):
    try:
        response = query_qmp(command, vmname)
        return response
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route('/cpu_usage/<vmname>')
def cpu_usage(vmname):
    try:
        return f"{get_cpu_usage(vmname)}\n"
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


if __name__ == "__main__":

    os.chdir("..");
    vmlist = get_vmlist()
 
    app.run(host='0.0.0.0')
