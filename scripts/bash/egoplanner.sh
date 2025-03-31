#!/bin/bash


# 启动 Docker 容器中的 VINS 节点
docker exec -it ros2-ego(容器名字，需要替换) bash -c "
cd ~/data/prj/ego-planner &&
source ./install/setup.bash &&
ros2 launch ego_planner single_run_in_sim.launch.py
"
