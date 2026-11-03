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

## Testing environments
This has been tested on an MBot omni with ubuntu 24.4 and ROS2 jazzy.

## Firmware
If the MBot has not be flashed with the ROS Omni firmware, follow the README at [mbot_firmware_ros_omni/README.md](mbot_firmware_ros_omni/README.md)

## Using the Workspaces

```bash
git clone https://github.com/Veldrovive/mbot_omni_stack.git --recurse-submodules --shallow-submodules
```

Before running the stack, you must build both the ROS bridge and the main ROS 2 workspace.

### 1. MBot ROS 2 Workspace
The MBot ROS 2 workspace contains all the boilerplate code for the MBot specific hardware. It will be used to run the sensors and SLAM.
> And navigation if you have a map you want to use.

#### Build the ROS 2 workspace
```bash
cd mbot_ros2_ws
rosdep update
rosdep install --from-paths src --ignore-src -r -y
colcon build
```

#### Running the LIDAR bringup
This script publishes the robot description and the LIDAR data.
```bash
cd mbot_ros2_ws
source install/setup.bash
ros2 launch mbot_bringup mbot_bringup.launch.py
```

#### Running the SLAM toolbox
```bash
cd mbot_ros2_ws
source install/setup.bash
ros2 launch mbot_navigation slam_toolbox_online_async_launch.py
```

### 2. MBot Bridge
The MBot bridge allows us to control the robot from languages besides c++. For more information, see the mbot bridge README.

#### Building the ROS bridge
```bash
cd mbot_bridge_ros/ws
rosdep update
rosdep install --from-paths src --ignore-src -r -y
colcon build
```

#### Running the ROS bridge
```bash
cd mbot_bridge_ros/ws
source install/setup.bash
ros2 launch rosbridge_server rosbridge_websocket_launch.xml
```

#### Testing the MBot bridge
Once the ROS bridge is running, we should be able to interact with the mbot. Make sure you have room for the mbot to move and then run the following.
```bash
cd mbot_bridge_ros/mbot_js
npm install
npm run test:bridge
```

#### Running as a service
To have the bridge start up with the MBot, follow the last section of [mbot_bridge_ros/README.md](mbot_bridge_ros/README.md) (starting from "Installing as a Systemd Service").

### 3. Web App
The web app allows for easy testing of the MBot.

#### Install dependencies
```bash
cd mbot_web_app_ros
npm install
```

#### Running in development mode
```bash
cd mbot_web_app_ros
npm run dev
```