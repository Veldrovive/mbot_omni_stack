#!/bin/bash

# MBot Omni Stack Bringup Script
# This script launches all necessary components for the MBot Omni Stack using tmux.

SESSION_NAME="mbot_omni"
WORKSPACE_DIR="/home/mbot/mbot_omni_stack"

# If the script is run from a different directory, try to adapt or use the provided path if running as a service
if [ ! -d "$WORKSPACE_DIR" ]; then
    WORKSPACE_DIR=$(pwd)
fi

echo "Starting MBot Omni Stack from $WORKSPACE_DIR..."

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null
if [ $? == 0 ]; then
    echo "Tmux session '$SESSION_NAME' already exists. Attaching to it..."
    tmux attach-session -t $SESSION_NAME
    exit 0
fi

# Create a new detached tmux session
tmux new-session -d -s $SESSION_NAME -n "bridge"

# Window 1: ROS Bridge Server
tmux send-keys -t $SESSION_NAME:bridge "cd $WORKSPACE_DIR/mbot_bridge_ros/ws && source install/setup.bash && ros2 launch rosbridge_server rosbridge_websocket_launch.xml" C-m

# Window 2: MBot Bringup (Lidar & Base)
tmux new-window -t $SESSION_NAME -n "bringup"
tmux send-keys -t $SESSION_NAME:bringup "cd $WORKSPACE_DIR/mbot_ros2_ws && source install/setup.bash && ros2 launch mbot_bringup mbot_bringup.launch.py" C-m

# Window 3: Navigation
tmux new-window -t $SESSION_NAME -n "nav"
tmux send-keys -t $SESSION_NAME:nav "cd $WORKSPACE_DIR/mbot_ros2_ws && source install/setup.bash && ros2 launch mbot_navigation navigation_launch.py" C-m

# Window 4: SLAM
tmux new-window -t $SESSION_NAME -n "slam"
tmux send-keys -t $SESSION_NAME:slam "cd $WORKSPACE_DIR/mbot_ros2_ws && source install/setup.bash && ros2 launch mbot_navigation slam_toolbox_online_async_launch.py" C-m

# Window 5: Web App
# Note: Using `npm run dev` for development. In a production environment, 
# you should serve a built static bundle (e.g., with nginx).
tmux new-window -t $SESSION_NAME -n "webapp"
tmux send-keys -t $SESSION_NAME:webapp "cd $WORKSPACE_DIR/mbot_web_app_ros && npm run dev" C-m

# Select the first window
tmux select-window -t $SESSION_NAME:bridge

# Check if we are running in an interactive terminal. If so, attach.
if [ -t 1 ]; then
    tmux attach-session -t $SESSION_NAME
else
    echo "Started detached tmux session '$SESSION_NAME'."
    echo "To view the logs, run: tmux attach -t $SESSION_NAME"
fi
