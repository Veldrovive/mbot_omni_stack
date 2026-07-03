# MBot Omni Stack

This repository contains the complete stack for the MBot, utilizing ROS 2 (Jazzy) for core robot operations, Nav2 for navigation, SLAM Toolbox for mapping, and a modern web stack for the user interface.

## Project Structure

The project is structured into three main submodules:
- `mbot_bridge_ros`: The ROS bridge providing a websocket interface for the web app to communicate with ROS.
- `mbot_ros2_ws`: The main ROS 2 workspace containing the `mbot_bringup` and `mbot_navigation` packages.
- `mbot_web_app_ros`: The Vite/React-based web interface for controlling and monitoring the robot.

## Prerequisites

- ROS 2 Jazzy installed
- Node.js (v18+) and npm installed
- Tmux installed (for process management during bringup)

## Building the Workspaces

Before running the stack, you must build both the ROS bridge and the main ROS 2 workspace.

### 1. Build the ROS Bridge
```bash
cd mbot_bridge_ros/ws
rosdep update
rosdep install --from-paths src --ignore-src -r -y
colcon build
```

### 2. Build the MBot ROS 2 Workspace
```bash
cd mbot_ros2_ws
rosdep update
rosdep install --from-paths src --ignore-src -r -y
colcon build
```

### 3. Install Web App Dependencies
```bash
cd mbot_web_app_ros
npm install
```

## Running the Stack

You can bring up the entire stack (ROS bridge, Lidar/Base bringup, Navigation, SLAM, and the Web App) using the provided script.

### Using the Bringup Script

Run the following command from the root of this repository:
```bash
./scripts/start_omni_stack.sh
```

This script starts a detached `tmux` session named `mbot_omni` and launches all necessary components in separate windows. 
- If you run the script interactively, it will automatically attach you to the `tmux` session so you can view the logs.
- You can navigate between the windows in `tmux` using `Ctrl-B` then `n` (next) or `p` (previous), or `Ctrl-B` followed by the window number.
- To detach from the session and leave it running in the background, press `Ctrl-B` then `d`.

### Running as a Systemd Service

To automatically start the entire stack on boot, you can install the provided systemd service.

```bash
sudo ./services/install_omni_stack_service.sh
```
This will install `mbot_omni_stack.service`, reload the systemd daemon, and enable/start the service. 

*Note on Production vs Development:*
The `start_omni_stack.sh` script currently uses `npm run dev` to serve the web application for development ease. For a full production deployment, it is recommended to run `npm run build` in the `mbot_web_app_ros` directory and serve the resulting static files using a high-performance web server like Nginx.
