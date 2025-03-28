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