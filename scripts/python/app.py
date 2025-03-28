from flask import Flask, request, jsonify
from flask_cors import CORS
import threading
import time 
import atexit
from ScriptController import ScriptController
from stop import kill_vins_processes, kill_ego_processes, kill_rtabmap_processes, kill_bag_processes
import argparse

app = Flask(__name__)
CORS(app)

# 定义命令行参数解析器
def parse_args():
    parser = argparse.ArgumentParser(description="Flask app to control script execution")
    parser.add_argument(
        '--script-path', 
        type=str, 
        required=True,  # 设置为必填参数
        help='Path to the directory containing the scripts (required)'
    )
    return parser.parse_args()


# 获取命令行参数
args = parse_args()
SCRIPT_PATH = args.script_path  # 从参数中获取脚本路径

# 初始化所有脚本控制器，传入路径参数
vins_controller = ScriptController(SCRIPT_PATH, 'vinsfusion.sh')
bag_controller = ScriptController(SCRIPT_PATH, 'bag.sh')
ego_controller = ScriptController(SCRIPT_PATH, 'egoplanner.sh')
rtab_controller = ScriptController(SCRIPT_PATH, 'rtabmap.sh')
target_controller = ScriptController(SCRIPT_PATH, 'set_target.sh')

@app.route('/hello', methods=['POST'])
def hello():
    stop()
    print("Starting VINS-Fusion demo")
    threading.Thread(target=start_vins_scripts).start()
    return jsonify({"message": "VINS-Fusion启动中..."}), 200

@app.route('/ego', methods=['POST'])
def ego():
    stop()
    print("Starting EgoPlanner")
    threading.Thread(target=start_ego_scripts).start()
    return jsonify({"message": "EgoPlanner启动中..."}), 200

@app.route('/rtab', methods=['POST'])
def rtab():
    stop()
    print("Starting RTABMap")
    threading.Thread(target=start_rtab_scripts).start()
    return jsonify({"message": "RTABMap启动中..."}), 200

@app.route('/set_target', methods=['POST'])
def set_target():
    data = request.json
    try:
        # 提取参数并进行简单校验
        x = float(data.get('x', 0))
        y = float(data.get('y', 0))
        z = float(data.get('z', 0))
    except ValueError:
        return jsonify({"error": "Invalid coordinates provided"}), 400
    
    def run_target_script():
        # 传递坐标参数给脚本
        target_controller.start(args=[str(x), str(y), str(z)])
    
    threading.Thread(target=run_target_script).start()
    return jsonify({"message": f"目标点设置中: ({x}, {y}, {z})"}), 200



# 各个启动函数
def start_vins_scripts():
    vins_controller.start()
    time.sleep(1)
    bag_controller.start()

def start_ego_scripts():
    ego_controller.start()

def start_rtab_scripts():
    rtab_controller.start()

# @app.route('/stop', methods=['POST'])
def stop():
    # 停止所有相关进程
    # 停止所有相关进程
    kill_vins_processes()
    kill_ego_processes()
    kill_rtabmap_processes()
    kill_bag_processes()
    # return jsonify({"message": "所有脚本已停止！"}), 200

# 定义一个清理函数
def cleanup():
    print("正在执行清理操作...")
    stop()
    print("清理完成，程序退出")

# 注册清理函数
atexit.register(cleanup)

if __name__ == '__main__':
    try:
        app.run(host='0.0.0.0', port=5000)
    except KeyboardInterrupt:
        print("检测到键盘中断，正在退出...")
    finally:
        # cleanup() 会通过 atexit 自动调用
        pass
