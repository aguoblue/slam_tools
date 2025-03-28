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