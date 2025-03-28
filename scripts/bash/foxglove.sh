#!/bin/bash
## 打开foxglove
cd ~/ws/foxglove_studio
source ~/ws/local/ego_planner_ros_humble/install/setup.bash
yarn web:serve &
## 打开foxglove-brige
ros2 launch foxglove_bridge foxglove_bridge_launch.xml
##http://localhost:8080/

