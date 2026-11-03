# MBot Omni Stack

This repository contains the complete stack for the MBot, utilizing ROS 2 (Jazzy) for core robot operations, Nav2 for navigation, SLAM Toolbox for mapping, and a modern web stack for the user interface.

## Project Structure

The project is made up of five submodules:
- `mbot_ros2_ws`: The main ROS 2 workspace. It contains `mbot_bringup` (robot description and LIDAR), `mbot_navigation` (SLAM Toolbox and Nav2 configs and launch files), `mbot_description`, `mbot_interfaces`, `mbot_vision`, `mbot_tools`, and the `sllidar_ros2` and `camera_ros` drivers.
- `mbot_bridge_ros`: The ROS bridge. It contains a `rosbridge_suite` workspace that gives clients a websocket interface to ROS, and `mbot_js`, a JavaScript library for controlling the MBot through that websocket.
- `mbot_web_app_ros`: The Vite/React web interface for controlling and monitoring the robot.
- `scratch-editor-mbot`: A Scratch editor with MBot blocks.
- `mbot_firmware_ros_omni`: The micro-ROS firmware for the MBot's Pico control board.

> `mbot_web_app_ros` and `scratch-editor-mbot` each contain their own copy of `mbot_bridge_ros` as a nested submodule, and they build `mbot_js` from that copy rather than from the top-level one. When you update `mbot_bridge_ros`, update all three copies to the same commit and rebuild `mbot_js` in each.

## Prerequisites

- **A base MBot image set up with [mbot_sys_utils](https://github.com/mbot-project/mbot_sys_utils)** (the `ros2_mbot_sys_utils` folder). Its install scripts set up ROS 2 Jazzy, the pico-sdk, the micro-ROS agent in `~/microros_ws`, the udev rule that names the control board's serial ports `/dev/mbot_microros` and `/dev/mbot_debug`, and the `mbot-microros-agent`, `mbot-start-network` and `mbot-oled` services. They also add these lines to `~/.bashrc`:
  ```bash
  export PICO_SDK_PATH=$HOME/pico-sdk
  source /opt/ros/jazzy/setup.bash
  export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
  export PICO_TOOLCHAIN_PATH=/usr/bin/
  source $HOME/microros_ws/install/local_setup.sh
  ```
  Every command below assumes ROS 2 is sourced, as those lines do. If your shell doesn't source it, run `source /opt/ros/jazzy/setup.bash` first.
- **The micro-ROS agent running.** It connects the firmware to ROS. Without it there is no odometry and the robot ignores velocity commands. The agent service starts on its own when the control board's USB port appears. Check it with `systemctl status mbot-microros-agent`.
- **Node.js (v18+) and npm.** Install them with [nvm](https://github.com/nvm-sh/nvm). The Scratch editor's start script requires nvm, not just Node.
- **Tmux** (for running the whole stack): `sudo apt install tmux`

## Testing environments
This has been tested on an MBot Omni with Ubuntu 24.04 and ROS 2 Jazzy.

## Firmware
If the MBot hasn't been flashed with the ROS Omni firmware, follow the README at [mbot_firmware_ros_omni/README.md](mbot_firmware_ros_omni/README.md).

## Using the Workspaces

```bash
git clone https://github.com/Veldrovive/mbot_omni_stack.git --recurse-submodules --shallow-submodules
```

Before running the stack, you must build both the ROS bridge and the main ROS 2 workspace.

### 1. MBot ROS 2 Workspace
The MBot ROS 2 workspace contains all the boilerplate code for the MBot specific hardware. It will be used to run the sensors and SLAM.
> And navigation if you have a map you want to use.

#### Build the ROS 2 workspace
The packages sit directly in `mbot_ros2_ws` (there is no `src/` folder), so rosdep is pointed at `.`:
```bash
cd mbot_ros2_ws
rosdep update
rosdep install --from-paths . --ignore-src -r -y
colcon build
```

> **Known issue:** `mbot_bringup.launch.py` loads `mbot_description/urdf/mbot_classic.urdf.xacro`. There is no Omni URDF yet, so the robot model, TF frames and footprint are the Classic's.

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
To have the bridge start up with the MBot, follow the "Running as a Service (Systemd)" section of [mbot_bridge_ros/README.md](mbot_bridge_ros/README.md).

### 3. Web App
The web app allows for easy testing of the MBot.

#### Install dependencies
The web app depends on `mbot_js` from its own nested copy, `mbot_web_app_ros/mbot_bridge_ros`. `mbot_js` has to be built before the web app can use it, because its build output (`dist/`) isn't checked in:
```bash
cd mbot_web_app_ros/mbot_bridge_ros/mbot_js
npm install
npm run build
cd ../..
npm install
```
Rebuild `mbot_js` whenever you update that nested copy.

#### Running in development mode
```bash
cd mbot_web_app_ros
npm run dev
```
Then open `http://<mbot-ip>:8000` in a browser.

### 4. Scratch Editor
The Scratch editor has its own setup, which builds the app into `/data/www/scratch` and installs the `mbot-scratch-gui` service. Follow [scratch-editor-mbot/README.md](scratch-editor-mbot/README.md). Once it's installed, the editor is served at `http://<mbot-ip>:8602` every time the MBot boots.

## Running the Whole Stack

Once everything above is built, start the whole stack in one tmux session (tmux must be installed separately, see [Prerequisites](#prerequisites)):

```bash
~/mbot_omni_stack/scripts/start_omni_stack.sh
```

This starts **mapping mode**: a tmux session called `mbot_omni` with one window per component: `bridge` (ROS bridge), `bringup` (LIDAR and robot description), `slam` (SLAM Toolbox) and `webapp` (web app dev server). If the session is already running, the script attaches to it.

To **navigate on a saved map** instead, pass the map's name (without `.yaml`):

```bash
~/mbot_omni_stack/scripts/start_omni_stack.sh --map my_map
```

This replaces the `slam` window with a `nav` window running Nav2 with AMCL localization on that map. SLAM and map-based navigation both publish `/map` and the `map → odom` transform, so only one runs at a time. To stop and switch modes, run `tmux kill-session -t mbot_omni` and start the script again. To make a map:

1. Start mapping mode and drive the robot around the area.
2. Save the map: `ros2 run nav2_map_server map_saver_cli -f ~/mbot_omni_stack/mbot_ros2_ws/mbot_navigation/maps/my_map`
3. Install it so the launch files can find it: `cd ~/mbot_omni_stack/mbot_ros2_ws && colcon build --packages-select mbot_navigation`

If the map isn't found, the script lists the maps that are installed, or tells you to rebuild if the map is only in the source `maps/` folder.

- Switch windows: click a window in the status bar, or `Ctrl-b` then the window number (`1`–`4`)
- Scroll back through output: mouse wheel (50,000 lines of history). Hold `Shift` while selecting text to copy with your terminal instead of tmux
- Detach and leave everything running: `Ctrl-b d`
- Reattach later: `tmux attach -t mbot_omni`
- Stop everything: `tmux kill-session -t mbot_omni`

The session uses [scripts/tmux.conf](scripts/tmux.conf), which turns on mouse support, raises the scrollback limit, numbers windows from 1 and adds `Ctrl-b |` / `Ctrl-b -` for splits. To use it for all your tmux sessions, run `ln -s ~/mbot_omni_stack/scripts/tmux.conf ~/.tmux.conf`.

> If the ROS bridge is already running (for example as the `mbot_bridge_ros` systemd service), the script doesn't start a second one. The `bridge` window shows a message saying the bridge is already running and where to find its logs.

To start the stack automatically on boot (in mapping mode) instead, run `sudo ./services/install_omni_stack_service.sh` from the repository root.