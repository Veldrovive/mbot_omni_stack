#!/bin/bash

# MBot Omni Stack Bringup Script
# This script launches all necessary components for the MBot Omni Stack using tmux.

SESSION_NAME="mbot_omni"
WORKSPACE_DIR="/home/mbot/mbot_omni_stack"

# If the script is run from a different directory, try to adapt or use the provided path if running as a service
if [ ! -d "$WORKSPACE_DIR" ]; then
    WORKSPACE_DIR=$(pwd)
fi

usage() {
    cat <<EOF
Usage: $(basename "$0") [--map <map_name>]

  (no arguments)     Mapping mode: ROS bridge, bringup, SLAM Toolbox and the web app.
  --map <map_name>   Navigation mode: ROS bridge, bringup, Nav2 + AMCL localization on a
                     saved map, and the web app. <map_name> is the map file name without
                     .yaml, from mbot_ros2_ws/mbot_navigation/maps/.

SLAM and map-based navigation both publish /map and the map->odom transform, so only
one of them runs at a time.
EOF
}

# ----- Parse arguments -----
MAP_NAME=""
while [ $# -gt 0 ]; do
    case "$1" in
        --map)
            if [ -z "$2" ]; then
                echo "ERROR: --map needs a map name." >&2
                usage >&2
                exit 1
            fi
            MAP_NAME="$2"
            shift 2
            ;;
        --map=*)
            MAP_NAME="${1#--map=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown argument '$1'." >&2
            usage >&2
            exit 1
            ;;
    esac
done

MAP_NAME="${MAP_NAME%.yaml}"
if [ -n "$MAP_NAME" ]; then
    MODE="navigation (map: $MAP_NAME)"
else
    MODE="mapping (SLAM)"
fi

# ----- Check the map exists before starting anything -----
# The launch files load the map from the *installed* share directory, which is a copy made
# by colcon build, so a map saved into the source maps/ folder needs a rebuild first.
if [ -n "$MAP_NAME" ]; then
    SRC_MAPS="$WORKSPACE_DIR/mbot_ros2_ws/mbot_navigation/maps"
    INSTALLED_MAPS="$WORKSPACE_DIR/mbot_ros2_ws/install/mbot_navigation/share/mbot_navigation/maps"
    if [ ! -f "$INSTALLED_MAPS/$MAP_NAME.yaml" ]; then
        if [ -f "$SRC_MAPS/$MAP_NAME.yaml" ]; then
            echo "ERROR: Map '$MAP_NAME' is in $SRC_MAPS but hasn't been installed yet." >&2
            echo "Rebuild so the launch files can find it:" >&2
            echo "  cd $WORKSPACE_DIR/mbot_ros2_ws && colcon build --packages-select mbot_navigation" >&2
        else
            echo "ERROR: Map '$MAP_NAME' not found." >&2
            AVAILABLE=$(ls "$INSTALLED_MAPS" 2>/dev/null | grep '\.yaml$' | sed 's/\.yaml$//' | tr '\n' ' ')
            if [ -n "$AVAILABLE" ]; then
                echo "Available maps: $AVAILABLE" >&2
            else
                echo "No maps are installed yet. Make one in mapping mode (run this script without --map)," >&2
                echo "save it with: ros2 run nav2_map_server map_saver_cli -f $SRC_MAPS/<map_name>" >&2
                echo "then run: cd $WORKSPACE_DIR/mbot_ros2_ws && colcon build --packages-select mbot_navigation" >&2
            fi
        fi
        exit 1
    fi
fi

echo "Starting MBot Omni Stack from $WORKSPACE_DIR in $MODE mode..."

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null
if [ $? == 0 ]; then
    RUNNING_MODE=$(tmux show-environment -t $SESSION_NAME MBOT_MODE 2>/dev/null | cut -d= -f2-)
    if [ -n "$RUNNING_MODE" ] && [ "$RUNNING_MODE" != "$MODE" ]; then
        echo "WARNING: Tmux session '$SESSION_NAME' is already running in $RUNNING_MODE mode, not $MODE mode."
        echo "To switch, stop it first: tmux kill-session -t $SESSION_NAME"
    fi
    echo "Tmux session '$SESSION_NAME' already exists. Attaching to it..."
    tmux attach-session -t $SESSION_NAME
    exit 0
fi

# Create a new detached tmux session using the stack's tmux config (mouse, scrollback, etc.).
# -f only applies if this starts the tmux server, so we also source it in case a server
# was already running (e.g. you had another tmux session open).
TMUX_CONF="$WORKSPACE_DIR/scripts/tmux.conf"
if [ -f "$TMUX_CONF" ]; then
    tmux -f "$TMUX_CONF" new-session -d -s $SESSION_NAME -n "bridge"
    tmux source-file "$TMUX_CONF"
else
    tmux new-session -d -s $SESSION_NAME -n "bridge"
fi
# Remember the mode so a later run can tell which one is already running
tmux set-environment -t $SESSION_NAME MBOT_MODE "$MODE"

# Window 1: ROS Bridge Server
# Skip launching if something is already listening on the rosbridge port (usually the
# mbot_bridge_ros systemd service); a second instance would just fail with "address in use".
ROSBRIDGE_PORT=9090
if ss -ltnH "sport = :$ROSBRIDGE_PORT" 2>/dev/null | grep -q .; then
    if systemctl is-active --quiet mbot_bridge_ros.service 2>/dev/null; then
        BRIDGE_MSG="ROS bridge is already running via the mbot_bridge_ros systemd service (port $ROSBRIDGE_PORT). Not starting another one. Logs: journalctl -u mbot_bridge_ros -f"
    else
        BRIDGE_MSG="Port $ROSBRIDGE_PORT is already in use, so the ROS bridge is assumed to be running elsewhere. Not starting another one. Check with: ss -ltnp 'sport = :$ROSBRIDGE_PORT'"
    fi
    echo "$BRIDGE_MSG"
    tmux send-keys -t $SESSION_NAME:bridge "clear; echo '$BRIDGE_MSG'" C-m
else
    tmux send-keys -t $SESSION_NAME:bridge "cd $WORKSPACE_DIR/mbot_bridge_ros/ws && source install/setup.bash && ros2 launch rosbridge_server rosbridge_websocket_launch.xml" C-m
fi

# Window 2: MBot Bringup (Lidar & Base)
tmux new-window -t $SESSION_NAME -n "bringup"
tmux send-keys -t $SESSION_NAME:bringup "cd $WORKSPACE_DIR/mbot_ros2_ws && source install/setup.bash && ros2 launch mbot_bringup mbot_bringup.launch.py" C-m

# Window 3: SLAM (mapping mode) or Nav2 on a saved map (navigation mode)
if [ -n "$MAP_NAME" ]; then
    tmux new-window -t $SESSION_NAME -n "nav"
    tmux send-keys -t $SESSION_NAME:nav "cd $WORKSPACE_DIR/mbot_ros2_ws && source install/setup.bash && ros2 launch mbot_navigation navigation_launch.py map_name:=$MAP_NAME" C-m
else
    tmux new-window -t $SESSION_NAME -n "slam"
    tmux send-keys -t $SESSION_NAME:slam "cd $WORKSPACE_DIR/mbot_ros2_ws && source install/setup.bash && ros2 launch mbot_navigation slam_toolbox_online_async_launch.py" C-m
fi

# Window 4: Web App
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
