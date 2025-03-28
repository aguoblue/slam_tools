<h2 id="YdyI5">开头说明</h2>
为什么用docker：隔离不同版本的开源项目需要用到的不同版本依赖

文件目录

![画板](https://cdn.nlark.com/yuque/0/2025/jpeg/43240353/1743145516065-495adce0-2057-40d4-99ed-0f0c0d8c1d6c.jpeg)

每次启动一个基础镜像为osrf/ros:humble-desktop的docker，挂载宿主机的data目录

每个docker负责编译对应的prj

为什么prj放在data目录：宿主机方便git下载，docker里面git可能超时，但git配置代理也可以

foxglove注意：有时候有些msg数据格式是slam项目自己定义的，而foxglove是依赖宿主机ros环境里识别到的数据，可能识别不了docker里面的msg数据格式。

<h2 id="W6gam">准备</h2>
<h3 id="CsDt5">构建vins容器</h3>
vins.bash

终端运行 bash vins.bash ~/自定义目录 容器名字

```bash
#!/bin/bash

# 打印格式化函数：固定总长度为50，动态调整分隔线
print_line() {
    local msg="$1"
    local total_length=50
    local msg_length=${#msg}
    local dash_length=$(( (total_length - msg_length - 2) / 2 ))
    local dashes=$(printf '=%.0s' $(seq 1 $dash_length))
    # 如果长度为奇数，右侧多一个=
    local extra_dash=$(( (total_length - msg_length - 2) % 2 ))
    printf "%s %s %s%s\n" "$dashes" "$msg" "$dashes" $([ $extra_dash -eq 1 ] && echo "=")
}

# 检查是否提供了足够参数
if [ $# -lt 2 ]; then
    print_line "参数错误"
    echo "错误：请提供两个参数："
    echo "  第一个参数：路径，例如 /home/user"
    echo "  第二个参数：Docker 容器名称，例如 ros2-vins1"
    echo "示例：./test1.sh /home/user ros2-vins1"
    exit 5
fi

# 将参数赋值给变量
YOUR_PATH=$1
CONTAINER_NAME=$2

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    print_line "Docker 未安装"
    echo "错误：请先安装 Docker（例如：sudo apt-get install docker.io）"
    exit 1
else
    print_line "Docker 已安装"
fi

# 安装 git
print_line "安装 Git"
sudo apt-get install -y git

# 创建目录
print_line "创建目录"
mkdir -p "$YOUR_PATH/data/prj/vins-fusion/ros2_ws/src"

# 检查并克隆 VINS-Fusion-ROS2 和 ceres-solver
print_line "克隆 VINS 和 Ceres"
cd "$YOUR_PATH/data/prj/vins-fusion/ros2_ws/src"
if [ ! -d "VINS-Fusion-ROS2" ]; then
    print_line "克隆 VINS-Fusion-ROS2"
    git clone https://github.com/bonabai/VINS-Fusion-ROS2
    cd VINS-Fusion-ROS2
    git checkout b02d4154e3d72fcd674f62a6347770cfc546fe48
    sed -i 's/rclcpp::Duration(0)/rclcpp::Duration(0,0)/g' loop_fusion/src/utility/CameraPoseVisualization.cpp
    sed -i 's/rclcpp::Duration(0)/rclcpp::Duration(0,0)/g' vins/src/utility/visualization.cpp
else
    print_line "VINS-Fusion-ROS2 已存在"
    echo "VINS-Fusion-ROS2 目录已存在，跳过克隆和修改。"
fi

cd "$YOUR_PATH/data/prj/vins-fusion/"
if [ ! -d "ceres-solver" ]; then
    print_line "克隆 Ceres-Solver"
    git clone https://github.com/ceres-solver/ceres-solver.git
    cd ceres-solver
    git checkout 2.1.0
else
    print_line "Ceres-Solver 已存在"
    echo "ceres-solver 目录已存在，跳过克隆。"
fi

# 检查是否存在同名 Docker 容器
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_line "容器检查"
    echo "容器 ${CONTAINER_NAME} 已存在，请用新的名字比如 ${CONTAINER_NAME}-new, 脚本终止。"
    exit 0
fi

# 创建并运行 Docker 容器
print_line "创建 Docker 容器"
echo "创建 Docker 容器 ${CONTAINER_NAME} 并执行编译..."
docker run -it \
    --name "${CONTAINER_NAME}" \
    --gpus all \
    -v "$YOUR_PATH/data:/root/data" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY=$DISPLAY \
    -e QT_X11_NO_MITSHM=1 \
    osrf/ros:humble-desktop \
    bash -c "
        print_line() { local m=\"\$1\"; local t=50; local ml=\${#m}; local dl=\$(( (t - ml - 2) / 2 )); local d=\$(printf '=%.0s' \$(seq 1 \$dl)); local e=\$(( (t - ml - 2) % 2 )); printf \"\$d \$m \$d%s\\n\" \$([ \$e -eq 1 ] && echo \"=\"); }
        print_line '更新包索引' &&
        apt-get update &&
        print_line '下载依赖' &&
        apt-get install libgoogle-glog-dev -y -q &&
        print_line '编译 Ceres-Solver' &&
        cd /root/data/prj/vins-fusion/ceres-solver &&
        rm -rf build/ &&
        mkdir -p build &&
        cd build &&
        cmake .. &&
        make -j4 &&
        make install &&
        print_line '编译 VINS-Fusion' &&
        cd /root/data/prj/vins-fusion/ros2_ws &&
        rm -rf build/ install/ log/ &&
        colcon build --symlink-install &&
        print_line '编译完成' &&
        print_line '编译完成，进入容器' &&
        bash
    "

print_line "脚本执行完成"
```

<h4 id="tAwrt">查看是否构建成功</h4>
```bash
source ./install/setup.bash
ros2 run vins vins_node ./src/VINS-Fusion-ROS2/config/euroc/euroc_stereo_config.yaml
```



<h3 id="IFuu0">构建 egoplanner 容器</h3>
ego.bash

终端运行 bash vins.bash  ~/自定义目录 容器名字

```bash
#!/bin/bash

# 打印格式化函数：固定总长度为50，动态调整分隔线
print_line() {
    local msg="$1"
    local total_length=50
    local msg_length=${#msg}
    local dash_length=$(( (total_length - msg_length - 2) / 2 ))
    local dashes=$(printf '=%.0s' $(seq 1 $dash_length))
    local extra_dash=$(( (total_length - msg_length - 2) % 2 ))
    printf "%s %s %s%s\n" "$dashes" "$msg" "$dashes" $([ $extra_dash -eq 1 ] && echo "=")
}

# 检查是否提供了足够参数
if [ $# -lt 2 ]; then
    print_line "参数错误"
    echo "错误：请提供两个参数："
    echo "  第一个参数：路径，例如 /home/user"
    echo "  第二个参数：Docker 容器名称，例如 ros2-ego1"
    echo "示例：./script.sh /home/user ros2-ego1"
    exit 1
fi

# 将参数赋值给变量
YOUR_PATH=$1
CONTAINER_NAME=$2

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    print_line "Docker 未安装"
    echo "错误：Docker 未安装，请先安装 Docker（例如：sudo apt-get install docker.io）"
    exit 1
else
    print_line "Docker 已安装"
fi

# 检查是否存在同名 Docker 容器
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_line "容器已存在"
    echo "容器 ${CONTAINER_NAME} 已存在，请用新的名字比如 ${CONTAINER_NAME}-new, 脚本终止。"
    exit 0
fi

# 创建目录
print_line "创建目录"
mkdir -p "$YOUR_PATH/data/prj/ego-planner"

# 克隆 ego_planner_ros_humble
print_line "克隆 Ego Planner"
cd "$YOUR_PATH/data/prj/ego-planner"
if [ ! -d "ego_planner_ros_humble" ]; then
    print_line "执行 Git Clone"
    git clone https://github.com/Kaede-Rukawa/ego_planner_ros_humble.git
else
    print_line "仓库已存在"
    echo "本地已存在 ego_planner_ros_humble 仓库，跳过克隆。"
fi

# 创建并运行 Docker 容器
print_line "创建 Docker 容器"
echo "创建 Docker 容器 ${CONTAINER_NAME} 并执行编译..."
docker run -it \
    --name "${CONTAINER_NAME}" \
    --gpus all \
    -v "$YOUR_PATH/data:/root/data" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY=$DISPLAY \
    -e QT_X11_NO_MITSHM=1 \
    osrf/ros:humble-desktop \
    bash -c "
        print_line() { local m=\"\$1\"; local t=50; local ml=\${#m}; local dl=\$(( (t - ml - 2) / 2 )); local d=\$(printf '=%.0s' \$(seq 1 \$dl)); local e=\$(( (t - ml - 2) % 2 )); printf \"\$d \$m \$d%s\\n\" \$([ \$e -eq 1 ] && echo \"=\"); }
        print_line '更新包索引' &&
        apt-get update &&
        print_line '安装 PCL-ROS' &&
        apt-get install -y -q ros-humble-pcl-ros &&
        print_line '编译 quadrotor_msgs' &&
        cd /root/data/prj/ego-planner/ego_planner_ros_humble &&
        rm -rf build/ install/ log/ &&
        colcon build --packages-select quadrotor_msgs --symlink-install &&
        print_line '设置环境' &&
        source ./install/setup.bash &&
        print_line '编译所有包' &&
        colcon build --symlink-install ;  # 用 ; 代替 &&，即使失败也继续
        print_line 'colcon build 是并行编译，可能出现某些包先编译好，但是依赖后面还没编译好的包' &&
        colcon build --symlink-install &&  # 第二次构建
        print_line '编译完成' &&
        echo '编译完成，进入容器' &&
        bash
    "   

print_line "脚本执行完成"
```

<h4 id="nTAHd">查看是否构建成功</h4>
```bash
source ./install/setup.bash &&
ros2 launch ego_planner single_run_in_sim.launch.py
```



<h3 id="PLg6z">foxglove</h3>
<h4 id="zhr4A">下载npm yarn </h4>
时间可能较长

```bash
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo bash -   #20.x的版本也可以
apt-get install -y nodejs
npm install -g yarn
```

<h4 id="IAGDF">下载 桥接库</h4>
```bash
sudo apt install ros-humble-foxglove-bridge

ros2 launch foxglove_bridge foxglove_bridge_launch.xml
```

<h4 id="Yg70e">下载foxglove</h4>
```bash
cd your_path/data/
git clone https://github.com/Russ76/foxglove_studio.git
cd foxglove_studio
yarn install 
yarn run
yarn web:serve
```



<h3 id="CISpz">其他脚本</h3>
<h4 id="FGto2">bag.sh</h4>
```cpp
cd your_path/ws/data/bag
ros2 bag play ./MH01
```

egoplanner.sh

```plain
#!/bin/bash


# 启动 Docker 容器中的 VINS 节点
docker exec -it ros2-ego(容器名字，需要替换) bash -c "
cd ~/data/prj/ego-planner &&
source ./install/setup.bash &&
ros2 launch ego_planner single_run_in_sim.launch.py
"
```

vinsfusion.sh

```plain
#!/bin/bash


# 启动 Docker 容器中的 VINS 节点
docker exec -it ros2-vins(容器名字，需要替换) bash -c "
cd ~/data/prj/vins-fusion/ros2_ws &&
source ./install/setup.bash &&
ros2 run vins vins_node ./src/vinsfusion/config/euroc/euroc_stereo_imu_config.yaml
"
```

set_target.sh

```plain
#!/bin/bash

# 检查是否提供了三个参数
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 x y z"
    exit 1
fi

# 获取命令行参数
X=$1
Y=$2
Z=$3

ros2 topic pub /move_base_simple/goal geometry_msgs/msg/PoseStamped "header:
  stamp:
    sec: 0
    nanosec: 0
  frame_id: ''
pose:
  position:
    x: $X
    y: $Y
    z: $Z
  orientation:
    x: 0.0
    y: 0.0
    z: 0.0
    w: 1.0"  --once
```

foxglove.sh

有时候有些msg数据格式是slam项目自己定义的，而foxglove是依赖宿主机ros环境里识别到的数据，可能识别不了docker里面的msg数据格式。

```plain
#!/bin/bash
## 打开foxglove
cd ~/ws/foxglove_studio
source ~/ws/local/ego_planner_ros_humble/install/setup.bash
yarn web:serve &
## 打开foxglove-brige
ros2 launch foxglove_bridge foxglove_bridge_launch.xml
##http://localhost:8080/
```



<h3 id="wO0Vd">conda 以及 python</h3>
conda创建一个python环境 3.10

运行

可能会出现**缺少依赖**，gpt提示下载即可，比如

No module named 'flask'

```bash
cd your_path/data/scripts/python
python3 app.py --script-path your_path/data/scripts/bash
```

<h4 id="SBC3c">python</h4>
app.py

```python
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

```

ScriptController.py

```python
import subprocess
import os
import time
import threading
import signal

class ScriptController:
    def __init__(self, script_path, script_name):
        self.script_path = script_path  # 脚本路径作为参数传入
        self.script_name = script_name
        self.process = None

    def start(self, args=None):
        """
        启动脚本
        args: 可选的命令行参数列表
        """
        try:
            command = ['bash', f'./{self.script_name}']
            if args:
                command.extend(args)  # 添加额外的命令行参数
                
            self.process = subprocess.Popen(
                command, 
                cwd=self.script_path  # 使用传入的路径
            )
            print(f"{self.script_name} 启动，PID: {self.process.pid}")
        except Exception as e:
            print(f"启动 {self.script_name} 失败: {e}")

    def is_running(self):
        """检查脚本是否在运行"""
        if self.process:
            return self.process.poll() is None
        return False

    def stop(self):
        """停止脚本"""
        if self.process:
            print(f"正在停止 {self.script_name}...")
            os.kill(self.process.pid, signal.SIGINT)  # 发送SIGINT信号，模拟Ctrl+C
            self.process.wait()  # 等待进程结束
            print(f"{self.script_name} 已停止")
            self.process = None

# def monitor_input(vins_controller, bag_controller):
#     while True:
#         user_input = input("输入 1 开始 VINS Fusion，输入 q 退出：")
#         if user_input == '1':
#             vins_controller.start()
#             time.sleep(2)  # 等待2秒
#             bag_controller.start()
#         elif user_input == 'q':
#             print("正在退出...")
#             bag_controller.stop()
#             vins_controller.stop()
#             break

# if __name__ == "__main__":
#     vins_controller = ScriptController('vinsfusion.sh')
#     bag_controller = ScriptController('bag.sh')

#     # 启动输入监控线程
#     input_thread = threading.Thread(target=monitor_input, args=(vins_controller, bag_controller))
#     input_thread.start()

#     # 等待输入线程结束
#     input_thread.join()
#     print("程序已结束")

```

stop.py

```python
import subprocess
import time
def kill_vins_processes():
    try:
        # 使用 sudo 调用 pkill 命令
        result = subprocess.run(['sudo', 'pkill', '-f', 'vins'], check=True, capture_output=True, text=True)
        print("pkill 输出:", result.stdout)
        print("成功终止所有包含 'vins' 的进程")
    except subprocess.CalledProcessError as e:
        print(f"终止过程中出现错误: {e.stderr}")


    # 等待片刻，再次确认是否还有相关进程
    time.sleep(1)  # 延迟1秒
    # 确认是否还有相关进程
    check_result = subprocess.run(['pgrep', '-f', 'vins'], capture_output=True, text=True)
    if check_result.stdout:
        print("仍有以下进程未被终止:", check_result.stdout)
    else:
        print("所有包含 'vins' 的进程已成功终止")

def kill_ego_processes():
    try:
        # 使用 sudo 调用 pkill 命令
        result = subprocess.run(['sudo', 'pkill', '-f', 'ego'], check=True, capture_output=True, text=True)
        print("pkill 输出:", result.stdout)
        print("成功终止所有包含 'ego' 的进程")
    except subprocess.CalledProcessError as e:
        print(f"终止过程中出现错误: {e.stderr}")

    # 等待片刻，再次确认是否还有相关进程
    time.sleep(1)  # 延迟1秒
    # 确认是否还有相关进程
    check_result = subprocess.run(['pgrep', '-f', 'ego'], capture_output=True, text=True)
    if check_result.stdout:
        print("仍有以下进程未被终止:", check_result.stdout)
    else:
        print("所有包含 'ego' 的进程已成功终止")

def kill_rtabmap_processes():
    try:
        # 使用 sudo 调用 pkill 命令
        result = subprocess.run(['sudo', 'pkill', '-f', 'rtabmap'], check=True, capture_output=True, text=True)
        print("pkill 输出:", result.stdout)
        print("成功终止所有包含 'rtabmap' 的进程")
    except subprocess.CalledProcessError as e:
        print(f"终止过程中出现错误: {e.stderr}")

    # 等待片刻，再次确认是否还有相关进程
    time.sleep(1)  # 延迟1秒
    # 确认是否还有相关进程
    check_result = subprocess.run(['pgrep', '-f', 'rtabmap'], capture_output=True, text=True)
    if check_result.stdout:
        print("仍有以下进程未被终止:", check_result.stdout)
    else:
        print("所有包含 'rtabmap' 的进程已成功终止")

def kill_bag_processes():
    try:
        # 使用 sudo 调用 pkill 命令，针对 ros2 bag
        result = subprocess.run(['sudo', 'pkill', '-f', 'ros2 bag'], check=True, capture_output=True, text=True)
        print("pkill 输出:", result.stdout)
        print("成功终止所有包含 'ros2 bag' 的进程")
    except subprocess.CalledProcessError as e:
        print(f"终止过程中出现错误: {e.stderr}")

    # 等待片刻，再次确认是否还有相关进程
    time.sleep(1)  # 延迟1秒
    # 确认是否还有相关进程
    check_result = subprocess.run(['pgrep', '-f', 'ros2 bag'], capture_output=True, text=True)
    if check_result.stdout:
        print("仍有以下进程未被终止:", check_result.stdout)
    else:
        print("所有包含 'ros2 bag' 的进程已成功终止")


```



<h2 id="BNTsI">前端页面</h2>
菜单栏 + 按钮

<h3 id="A4DBV">index.html</h3>
```html
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>按钮示例</title>
    <link rel="stylesheet" href="styles.css">
    <script src="scripts.js" defer></script>
</head>
<body>
    <div class="nav-bar">
        <button class="nav-button active" onclick="switchContent('vinsfusion')">VINSFusion</button>
        <button class="nav-button" onclick="switchContent('egoplanner')">EgoPlanner</button>
        <button class="nav-button" onclick="switchContent('rtabmap')">RTABMap</button>
    </div>

    <div id="vinsfusion" class="content-page">
        <div class="button-response-row">
            <!-- <span>VINS-Fusion状态监控</span> -->
            <button id="helloButton">启动demo</button>
            <div id="responseMessage" class="response-area"></div>
        </div>

    </div>

    <div id="egoplanner" class="content-page" style="display: none;">
        <div class="button-response-row">
            <!-- <span>EgoPlanner 控制面板</span> -->
            <button id="egoButton">启动</button>
            <div id="egoResponse" class="response-area"></div>
        </div>
        <div class="button-input-row">
            <button id="setPointButton">设置目标点</button>
            <div class="coordinate-inputs">
                <div class="input-group">
                    <label for="x-coord">X:</label>
                    <input type="number" id="x-coord" step="0.1" value="0.0" placeholder="0.0">
                </div>
                <div class="input-group">
                    <label for="y-coord">Y:</label>
                    <input type="number" id="y-coord" step="0.1" value="0.0" placeholder="0.0">
                </div>
                <div class="input-group">
                    <label for="z-coord">Z:</label>
                    <input type="number" id="z-coord" step="0.1" value="0.0" placeholder="0.0">
                </div>
            </div>
        </div>
    </div>
    
    <div id="rtabmap" class="content-page" style="display: none;">
        <div class="button-response-row">
            <!-- <span>RTABMap 监控界面</span> -->
            <button id="rtabButton">启动demo</button>
            <div id="rtabResponse" class="response-area"></div>
        </div>
    </div>
    <iframe id="foxgloveFrame" src="http://127.0.0.1:8080" title="foxglove"></iframe>
</body>
</html>

```

<h3 id="vFB6a">js</h3>
scripts.js

```javascript
document.getElementById('helloButton').addEventListener('click', function() {
    fetch('http://127.0.0.1:5000/hello', {
        method: 'POST',
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('responseMessage').innerText = data.message;
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('responseMessage').innerText = "请求失败";
    });
    refreshIframe();
});

document.getElementById('egoButton').addEventListener('click', function() {
    fetch('http://127.0.0.1:5000/ego', {
        method: 'POST',
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('egoResponse').innerText = data.message;
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('egoResponse').innerText = "请求失败";
    });
    refreshIframe();
});

document.getElementById('rtabButton').addEventListener('click', function() {
    fetch('http://127.0.0.1:5000/rtab', {
        method: 'POST',
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('rtabResponse').innerText = data.message;
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('rtabResponse').innerText = "请求失败";
    });
    refreshIframe();
});

document.getElementById('setPointButton').addEventListener('click', function() {
    const x = document.getElementById('x-coord').value;
    const y = document.getElementById('y-coord').value;
    const z = document.getElementById('z-coord').value;
    
    fetch('http://127.0.0.1:5000/set_target', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            x: parseFloat(x),
            y: parseFloat(y),
            z: parseFloat(z)
        })
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('egoResponse').innerText = data.message;
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('egoResponse').innerText = "设置目标点失败";
    });
});

function switchContent(pageId) {
    document.querySelectorAll('.content-page').forEach(page => {
        page.style.display = 'none';
    });
    
    document.getElementById(pageId).style.display = 'block';
    
    document.querySelectorAll('.nav-button').forEach(button => {
        button.classList.remove('active');
    });
    document.querySelector(`[onclick="switchContent('${pageId}')"]`).classList.add('active');
}

function refreshIframe() {
    const frame = document.getElementById('foxgloveFrame');
    frame.src = frame.src;
}

```

<h3 id="FTeuH">css</h3>
style.css

```css
body {
    margin: 0;
    display: flex;
    flex-direction: column;
    height: 100vh;
    font-family: 'Arial', sans-serif;
}

.nav-bar {
    background-color: #2c3e50;
    padding: 0;
    display: flex;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.nav-button {
    color: #ecf0f1;
    background: none;
    border: none;
    padding: 15px 25px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 500;
    transition: background-color 0.3s, color 0.3s;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.nav-button:hover {
    background-color: #34495e;
}

.nav-button.active {
    background-color: #3498db;
    color: white;
}

.content-page {
    padding: 20px;
    flex-grow: 1;
    background-color: #f5f6fa;
}

h2 {
    color: #2c3e50;
    margin-bottom: 20px;
}

iframe {
    width: 100%;
    height: calc(100vh - 120px);
    border: none;
    border-radius: 4px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.button-response-row {
    display: flex;
    align-items: center;
    gap: 20px;
    margin-top: 10px;
}

.button-response-row button {
    padding: 8px 16px;
    background-color: #3498db;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 0.3s;
}

.button-response-row button:hover {
    background-color: #2980b9;
}

.button-response-row div {
    margin: 0;
    padding: 10px;
    background-color: white;
    border-radius: 4px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    flex-grow: 1;
}

.response-area {
    margin: 0;
    padding: 10px;
    background-color: white;
    border-radius: 4px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    flex-grow: 1;
    min-height: 20px;
    min-width: 200px;
}

.button-input-row {
    display: flex;
    align-items: center;
    gap: 20px;
    margin: 10px 0;
}

.coordinate-inputs {
    display: flex;
    gap: 15px;
}

.input-group {
    display: flex;
    align-items: center;
    gap: 5px;
}

.input-group label {
    font-weight: bold;
    color: #2c3e50;
}

.input-group input {
    width: 80px;
    padding: 6px;
    border: 1px solid #bdc3c7;
    border-radius: 4px;
    text-align: right;
}

.input-group input:focus {
    outline: none;
    border-color: #3498db;
    box-shadow: 0 0 3px rgba(52, 152, 219, 0.3);
}

#setPointButton {
    padding: 8px 16px;
    background-color: #3498db;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 0.3s;
}

#setPointButton:hover {
    background-color: #2980b9;
} 
```



---

<h2 id="Q2air">反向代理</h2>
frp + nginx

<h3 id="rIgzo">服务器</h3>
<h4 id="qIaKV">服务器ip </h4>
106.53.217.117

根据自己开通的服务器ip，更换下面配置文件里所有的ip

<h4 id="e8YAd">frps</h4>
```bash
./frps -c frps.ini
```

frps.init

```plain
[common]
bind_port = 7000
```

<h4 id="EpKJQ">nginx</h4>
nginx.conf

```plain
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user lighthouse;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
   # include /etc/nginx/conf.d/*.conf;

  server {
      listen 11111;
      server_name 106.53.217.117;

      # 配置反向代理到本地服务

      # 代理 WebSocket 请求到本地的 11113 端口
      location /websocket/ {
          rewrite ^/websocket/(.*)$ /$1 break;  # 去掉 /websocket/ 前缀，转发到本地服务
          proxy_pass http://127.0.0.1:11113;  # 将请求转发到本地的 11113 端口
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;  # WebSocket 协议要求
          proxy_set_header Connection 'upgrade';  # WebSocket 协议要求
          proxy_set_header Host $host;
      }

      # 代理 HTTP 请求到本地的 11112 端口
      location /http/ {
          rewrite ^/http/(.*)$ /$1 break;  # 重写路径，使其符合本地服务的路径
          proxy_pass http://127.0.0.1:11112;  # 将请求转发到本地的 11112 端口
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
      }


      location /hello {
          proxy_pass http://127.0.0.1:11114/hello;  # 将请求转发到通过 FRP 映射的 11114 端口
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
      }

      location /ego {
          proxy_pass http://127.0.0.1:11114/ego;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
      }

      location /rtab {
          proxy_pass http://127.0.0.1:11114/rtab;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
      }

      location /set_target {
          proxy_pass http://127.0.0.1:11114/set_target;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
      }


      # 默认页面处理
      location / {
          root /home/lighthouse/dist-slam;  # 如果有默认的 index.html
          index index.html;
          try_files $uri $uri/ /index.html;
      }
  }


}


```

nginx代理的html

```plain
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>按钮示例</title>
    <link rel="stylesheet" href="styles.css">
    <script src="scripts.js" defer></script>
</head>
<body>
    <div class="nav-bar">
        <button class="nav-button active" onclick="switchContent('vinsfusion')">VINSFusion</button>
        <button class="nav-button" onclick="switchContent('egoplanner')">EgoPlanner</button>
        <button class="nav-button" onclick="switchContent('rtabmap')">RTABMap</button>
    </div>

    <div id="vinsfusion" class="content-page">
        <div class="button-response-row">
            <!-- <span>VINS-Fusion状态监控</span> -->
            <button id="helloButton">启动demo</button>
            <div id="responseMessage" class="response-area"></div>
        </div>

    </div>

    <div id="egoplanner" class="content-page" style="display: none;">
        <div class="button-response-row">
            <!-- <span>EgoPlanner 控制面板</span> -->
            <button id="egoButton">启动</button>
            <div id="egoResponse" class="response-area"></div>
        </div>
        <div class="button-input-row">
            <button id="setPointButton">设置目标点</button>
            <div class="coordinate-inputs">
                <div class="input-group">
                    <label for="x-coord">X:</label>
                    <input type="number" id="x-coord" step="0.1" value="0.0" placeholder="0.0">
                </div>
                <div class="input-group">
                    <label for="y-coord">Y:</label>
                    <input type="number" id="y-coord" step="0.1" value="0.0" placeholder="0.0">
                </div>
                <div class="input-group">
                    <label for="z-coord">Z:</label>
                    <input type="number" id="z-coord" step="0.1" value="0.0" placeholder="0.0">
                </div>
            </div>
        </div>
    </div>
    
    <div id="rtabmap" class="content-page" style="display: none;">
        <div class="button-response-row">
            <!-- <span>RTABMap 监控界面</span> -->
            <button id="rtabButton">启动demo</button>
            <div id="rtabResponse" class="response-area"></div>
        </div>
    </div>
    <iframe id="foxgloveFrame" src="http://106.53.217.117:11111/http/" title="foxglove"></iframe>
</body>
</html>

```

```plain
document.getElementById('helloButton').addEventListener('click', function() {
    fetch('http://106.53.217.117:11111/hello', {
        method: 'POST',
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('responseMessage').innerText = data.message;
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('responseMessage').innerText = "请求失败";
    });
    refreshIframe();
});

document.getElementById('egoButton').addEventListener('click', function() {
    fetch('http://106.53.217.117:11111/ego', {
        method: 'POST',
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('egoResponse').innerText = data.message;
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('egoResponse').innerText = "请求失败";
    });
    refreshIframe();
});

document.getElementById('rtabButton').addEventListener('click', function() {
    fetch('http://106.53.217.117:11111/rtab', {
        method: 'POST',
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('rtabResponse').innerText = data.message;
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('rtabResponse').innerText = "请求失败";
    });
    refreshIframe();
});

document.getElementById('setPointButton').addEventListener('click', function() {
    const x = document.getElementById('x-coord').value;
    const y = document.getElementById('y-coord').value;
    const z = document.getElementById('z-coord').value;
    
    fetch('http://106.53.217.117:11111/set_target', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            x: parseFloat(x),
            y: parseFloat(y),
            z: parseFloat(z)
        })
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('egoResponse').innerText = data.message;
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('egoResponse').innerText = "设置目标点失败";
    });
});

function switchContent(pageId) {
    document.querySelectorAll('.content-page').forEach(page => {
        page.style.display = 'none';
    });
    
    document.getElementById(pageId).style.display = 'block';
    
    document.querySelectorAll('.nav-button').forEach(button => {
        button.classList.remove('active');
    });
    document.querySelector(`[onclick="switchContent('${pageId}')"]`).classList.add('active');
}

function refreshIframe() {
    const frame = document.getElementById('foxgloveFrame');
    frame.src = frame.src;
}

```

```plain
body {
    margin: 0;
    display: flex;
    flex-direction: column;
    height: 100vh;
    font-family: 'Arial', sans-serif;
}

.nav-bar {
    background-color: #2c3e50;
    padding: 0;
    display: flex;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.nav-button {
    color: #ecf0f1;
    background: none;
    border: none;
    padding: 15px 25px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 500;
    transition: background-color 0.3s, color 0.3s;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.nav-button:hover {
    background-color: #34495e;
}

.nav-button.active {
    background-color: #3498db;
    color: white;
}

.content-page {
    padding: 20px;
    flex-grow: 1;
    background-color: #f5f6fa;
}

h2 {
    color: #2c3e50;
    margin-bottom: 20px;
}

iframe {
    width: 100%;
    height: calc(100vh - 120px);
    border: none;
    border-radius: 4px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.button-response-row {
    display: flex;
    align-items: center;
    gap: 20px;
    margin-top: 10px;
}

.button-response-row button {
    padding: 8px 16px;
    background-color: #3498db;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 0.3s;
}

.button-response-row button:hover {
    background-color: #2980b9;
}

.button-response-row div {
    margin: 0;
    padding: 10px;
    background-color: white;
    border-radius: 4px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    flex-grow: 1;
}

.response-area {
    margin: 0;
    padding: 10px;
    background-color: white;
    border-radius: 4px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    flex-grow: 1;
    min-height: 20px;
    min-width: 200px;
}

.button-input-row {
    display: flex;
    align-items: center;
    gap: 20px;
    margin: 10px 0;
}

.coordinate-inputs {
    display: flex;
    gap: 15px;
}

.input-group {
    display: flex;
    align-items: center;
    gap: 5px;
}

.input-group label {
    font-weight: bold;
    color: #2c3e50;
}

.input-group input {
    width: 80px;
    padding: 6px;
    border: 1px solid #bdc3c7;
    border-radius: 4px;
    text-align: right;
}

.input-group input:focus {
    outline: none;
    border-color: #3498db;
    box-shadow: 0 0 3px rgba(52, 152, 219, 0.3);
}

#setPointButton {
    padding: 8px 16px;
    background-color: #3498db;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 0.3s;
}

#setPointButton:hover {
    background-color: #2980b9;
} 
```

然后启动nginx，访问106.53.217.117:11111可以看到html

```plain
106.53.217.117:11111
```

foxglove需要websocket来传输数据

open connection

websocket URL

```plain
ws://106.53.217.117:11111/websocket/
```

<h3 id="TKW3K">本地</h3>
<h4 id="BbnKP">frpc</h4>
frpc.init

```css
./frpc -c frpc.ini
```

```plain
[common]
# 服务器的公网 IP 地址，用于 FRP 客户端连接到 FRP 服务端
server_addr = 106.53.217.117

# FRP 服务端监听的端口
# 默认是 7000，客户端会连接该端口以建立连接
server_port = 7000

[http]
# 定义一个名为 http 的隧道配置
type = tcp
# 本地服务的 IP 地址，这里设置为 localhost (127.0.0.1)，即本地机器
local_ip = 127.0.0.1
# 本地服务的端口，这里假设本地服务运行在 8080 端口
local_port = 8080
# 外网访问该服务的端口，设置为 11112，表示 FRP 将本地 8080 端口的流量转发到外部的 11112 端口
remote_port = 11112

[foxglove_bridge]
# 定义一个名为 foxglove_bridge 的 WebSocket 隧道配置
type = tcp
# 本地 WebSocket 服务的 IP 地址，这里设置为 localhost (127.0.0.1)
local_ip = 127.0.0.1
# 本地 WebSocket 服务的端口，这里是 8765
local_port = 8765
# 外网访问 WebSocket 服务的端口，设置为 11113
remote_port = 11113

[app.py]
# 按钮的通道
type = tcp
# 本地 WebSocket 服务的 IP 地址，这里设置为 localhost (127.0.0.1)
local_ip = 127.0.0.1
# 本地 WebSocket 服务的端口，这里是 8765
local_port = 5000
# 外网访问 WebSocket 服务的端口，设置为 11114
remote_port = 11114
```



<h2 id="N9SAv">公网ip访问</h2>
公网服务器已过期，且公网访问数据可视化较迟钝，











