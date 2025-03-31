#!/bin/bash


# 启动 Docker 容器中的 VINS 节点
docker exec -it ros2-vins(容器名字，需要替换) bash -c "
cd ~/data/prj/vins-fusion/ros2_ws &&
source ./install/setup.bash &&
ros2 run vins vins_node ./src/vinsfusion/config/euroc/euroc_stereo_imu_config.yaml
"


