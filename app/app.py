import os
import subprocess
from flask import Flask, send_file, jsonify, request

app = Flask(__name__)

vm_list = []

def get_vmlist():

    vm_list.clear()

    for filename in os.listdir(f'etc'):
        if filename.endswith('.conf'):
            with open(f'etc/{filename}', 'r') as f:
                lines = f.readlines()
                vm_name = next((line for line in lines if line.startswith('vm=')), None).split('=')[1].strip()

            # Check if QEMU process is running 
            pid_file = f'qemu-{filename.replace(".conf", "")}.pid' 
            if os.path.exists(pid_file):
                status = 'running'
            else:
                status = 'stopped'
            vm_list.append({'name': vm_name, 'status': status})

    return vm_list

def get_vm(vmname):
    for vm in get_vmlist():
        if vm['name'] == vmname:
            return vm

@app.route("/")
def index():
    # do not render template, frontend logic handled by Vue
    return send_file("index.html")


@app.route("/vmlist")
def vmlist():
    return jsonify(get_vmlist())

@app.route("/getvm/<vmname>")
def getvm(vmname):
    return jsonify(get_vm(vmname))

@app.route("/start", methods=["POST"])
def start_vm():
    vm_name = request.json.get("vm_name")

    config_file = f'etc/{vm_name}.conf'

    if not os.path.exists(config_file):
        return jsonify({"success": False, "message": "Config file not found"}), 404

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
        return jsonify({"success": False, "message": "PID file not found"}), 404

    try:
        with open(pid_file, 'r') as f:
            pid = f.read().strip()
        os.kill(int(pid), 15)
        return jsonify({"success": True, "message": "Stopping VM"})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


if __name__ == "__main__":

    os.chdir("..");
    vm_list = get_vmlist()
 
    app.run(host='0.0.0.0')
