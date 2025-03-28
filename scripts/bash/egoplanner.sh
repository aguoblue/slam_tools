#!/bin/bash


# 启动 Docker 容器中的 VINS 节点
docker exec -it ros2-ego bash -c "
cd ~/ego_planner_ros_humble &&
source ./install/setup.bash &&
ros2 launch ego_planner single_run_in_sim.launch.py
"
