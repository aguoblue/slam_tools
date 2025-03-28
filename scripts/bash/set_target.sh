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