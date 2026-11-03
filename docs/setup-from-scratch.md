# Setting up an MBot from scratch

This takes an MBot Omni from a blank SD card to a working bot with the ROS 2 stack, the web app and the Scratch editor. Do the parts in order, because later parts depend on earlier ones. Building everything on the Pi takes a few hours, mostly in parts 1 and 6.

Every path in these steps, and in the service files they install, assumes the user is `mbot` and the home folder is `/home/mbot`. If you use a different username, you'll have to edit the `.service` files before installing them.

Tested on a Raspberry Pi 5 running Ubuntu 24.04.3 LTS with ROS 2 Jazzy.

## Contents
1. [Flash the OS](#1-flash-the-os)
2. [Install the base system with mbot_sys_utils](#2-install-the-base-system-with-mbot_sys_utils)
3. [Set the bot's name and Wi-Fi](#3-set-the-bots-name-and-wi-fi)
4. [Clone this repository](#4-clone-this-repository)
5. [Flash the firmware (new or replaced Pico only)](#5-flash-the-firmware-new-or-replaced-pico-only)
6. [Build the ROS 2 workspace](#6-build-the-ros-2-workspace)
7. [Install Node.js](#7-install-nodejs)
8. [Set up the ROS bridge](#8-set-up-the-ros-bridge)
9. [Set up the web app](#9-set-up-the-web-app)
10. [Set up the Scratch editor](#10-set-up-the-scratch-editor)
11. [Choose how the stack starts](#11-choose-how-the-stack-starts)
12. [Check everything works](#12-check-everything-works)

---

## 1. Flash the OS

1. With Raspberry Pi Imager, flash **Ubuntu 24.04 LTS (64-bit)** for Raspberry Pi onto the SD card.
2. In the Imager's settings, create the user **`mbot`** and turn on SSH.
3. Boot the Pi, log in as `mbot`, and get it online. Use Ethernet or any Wi-Fi network for now; part 3 sets up the bot's permanent network settings.

## 2. Install the base system with mbot_sys_utils

[mbot_sys_utils](https://github.com/mbot-project/mbot_sys_utils) installs everything the stack expects to already be on the bot. These steps follow its `ros2_mbot_sys_utils/README.md`; check there if anything has changed.

```bash
cd ~
git clone https://github.com/mbot-project/mbot_sys_utils.git
cd ~/mbot_sys_utils/ros2_mbot_sys_utils/install_scripts
```

Run each script from that folder, in this order:

```bash
./install_mbot_dependencies.sh   # build tools, Pico toolchain, ~/pico-sdk, picotool, mbot-upload-firmware
./install_ros2_jazzy.sh          # ROS 2 Jazzy, Nav2, SLAM Toolbox, rviz2, xacro, teleop
source ~/.bashrc
./install_microros.sh            # micro-ROS agent, built in ~/microros_ws
./install_camera.sh              # libcamera and rpicam-apps built from source, plus ROS image packages
```

These scripts add the following lines to `~/.bashrc`. Every later step assumes they're there:

```bash
export PICO_SDK_PATH=/home/mbot/pico-sdk
source /opt/ros/jazzy/setup.bash
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export PICO_TOOLCHAIN_PATH=/usr/bin/
source /home/mbot/microros_ws/install/local_setup.sh
```

Then install the udev rules and services:

```bash
cd ~/mbot_sys_utils/ros2_mbot_sys_utils/udev_rules
./install_rules.sh               # /dev/mbot_microros and /dev/mbot_debug names; adds mbot to the video group

cd ~/mbot_sys_utils/ros2_mbot_sys_utils/services
./install_mbot_ros_services.sh   # mbot-start-network, mbot-microros-agent, mbot-oled
```

**On the University of Michigan network:** download the SecureW2 JoinNow installer to your home folder from [SecureW2's UMich page](https://cloud.securew2.com/public/92472/UMich-WiFi/) and run it to enrol the bot on MWireless.

## 3. Set the bot's name and Wi-Fi

`mbot-start-network` reads `/boot/firmware/mbot_config.txt` every time the bot boots. Copy the template, then edit it:

```bash
sudo cp ~/mbot_sys_utils/ros2_mbot_sys_utils/mbot_config.txt /boot/firmware/
sudo nano /boot/firmware/mbot_config.txt
```

```ini
mbot_hostname=mbot-0000          # this bot's hostname, e.g. mbot-aidan
mbot_ap_password=iloverobots     # password for the bot's fallback hotspot
new_wifi_ssid=HomeWifiSSID       # network to join on boot
new_wifi_password=HomeWifiPassword
autostart=run                    # run | bootload | disable: what the Pico does at boot
```

At boot, the service sets the hostname. If the bot isn't already on Wi-Fi, it joins `new_wifi_ssid` when that network is in range. Otherwise it starts its own hotspot, named `<hostname>-AP`, with the bot at `192.168.3.1`. It also starts the Pico according to `autostart`. Leave it on `run`.

Reboot so the hostname, group membership and services take effect:

```bash
sudo reboot
```

## 4. Clone this repository

```bash
cd ~
git clone https://github.com/Veldrovive/mbot_omni_stack.git --recurse-submodules --shallow-submodules
sudo apt install -y tmux
```

It must end up at `/home/mbot/mbot_omni_stack`, because the service files hardcode that path.

## 5. Flash the firmware (new or replaced Pico only)

The firmware is stored on the Pico, not the SD card. If you're rebuilding the SD card for a bot that already worked, skip to part 6.

```bash
cd ~/mbot_omni_stack/mbot_firmware_ros_omni
mkdir -p build && cd build
cmake ..
make mbot_omni_ros mbot_calibrate_omni

# Put the bot on the floor with room to move. Calibration drives the wheels.
sudo mbot-upload-firmware flash mbot_calibrate_omni.uf2   # wait until the robot stops moving
sudo mbot-upload-firmware flash mbot_omni_ros.uf2
```

Once the main firmware is running, `ls -l /dev/mbot_*` should show `/dev/mbot_microros` and `/dev/mbot_debug`. `systemctl status mbot-microros-agent` should then show the agent running, because udev starts it as soon as `/dev/mbot_microros` appears.

More detail is in the [firmware README](../mbot_firmware_ros_omni/README.md).

## 6. Build the ROS 2 workspace

```bash
cd ~/mbot_omni_stack/mbot_ros2_ws
rosdep update
rosdep install --from-paths . --ignore-src -r -y --skip-keys=libcamera
colcon build
echo "source /home/mbot/mbot_omni_stack/mbot_ros2_ws/install/local_setup.bash" >> ~/.bashrc
source ~/.bashrc
```

- `--from-paths .`: the packages sit directly in `mbot_ros2_ws`; there's no `src/` folder.
- `--skip-keys=libcamera`: libcamera was already built from source in part 2. Without this flag, rosdep would install a second copy from apt.

## 7. Install Node.js

The web app, `mbot_js` and Scratch all need Node.js. Scratch's service specifically loads Node 22 through nvm, so install it that way:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash
source ~/.bashrc
nvm install 22
nvm alias default 22
```

## 8. Set up the ROS bridge

The bridge is a `rosbridge_suite` server. It exposes ROS over a websocket on port 9090, and the web app, Scratch and `mbot_js` all connect through it.

```bash
cd ~/mbot_omni_stack/mbot_bridge_ros/ws
rosdep install --from-paths src --ignore-src -r -y
colcon build

# Start it on every boot
sudo ~/mbot_omni_stack/mbot_bridge_ros/services/install_ros_bridge_service.sh
```

To test it, run the following with the bot on the floor and room to move. The test drives the robot.

```bash
cd ~/mbot_omni_stack/mbot_bridge_ros/mbot_js
npm install
npm run test:bridge
```

## 9. Set up the web app

The web app uses `mbot_js` from its own nested copy of the bridge repository, so that copy has to be built first. Its build output isn't checked in.

```bash
cd ~/mbot_omni_stack/mbot_web_app_ros/mbot_bridge_ros/mbot_js
npm install
npm run build

cd ~/mbot_omni_stack/mbot_web_app_ros
npm install
npm run dev     # then open http://<mbot-ip>:8000; Ctrl-C to stop
```

## 10. Set up the Scratch editor

This builds Scratch into a static site in `/data/www/scratch` and installs a service that serves it on port 8602. The build is large and slow on a Pi.

```bash
cd ~/mbot_omni_stack/scratch-editor-mbot
./install_scripts/install.sh       # builds and copies to /data/www/scratch, installs `serve` globally
./services/install_service.sh      # installs and starts mbot-scratch-gui
./install_scripts/cleanup.sh       # optional: deletes node_modules and build caches to free SD card space
```

More detail is in the [Scratch README](../scratch-editor-mbot/README.md).

## 11. Choose how the stack starts

At this point the agent, bridge, Scratch, networking and OLED services start on boot. The robot-side nodes (LIDAR bringup, and SLAM or Nav2) and the web app don't. Choose based on how the bot will be used:

- **Teaching bot** (students launch bringup and SLAM themselves): stop here. If anything else also launched them, students would get two LIDAR drivers fighting over `/dev/ttyUSB0` and two `map → odom` publishers.
- **Start by hand when needed:** run `~/mbot_omni_stack/scripts/start_omni_stack.sh`, or add `--map <name>` for navigation on a saved map. See [Running the Whole Stack](../README.md#running-the-whole-stack).
- **Self-starting bot** (everything up on boot, in mapping mode):
  ```bash
  cd ~/mbot_omni_stack
  sudo ./services/install_omni_stack_service.sh
  ```

Optionally, use the stack's tmux settings for all your tmux sessions:

```bash
ln -s ~/mbot_omni_stack/scripts/tmux.conf ~/.tmux.conf
```

## 12. Check everything works

Reboot first (`sudo reboot`), then check:

| Check | Command or action | Expected |
| --- | --- | --- |
| Hostname and network | `hostname`; look at the OLED | Your `mbot_hostname`, with an IP address on the OLED |
| Control board connected | `ls -l /dev/mbot_*` | `/dev/mbot_microros` and `/dev/mbot_debug` |
| micro-ROS agent | `systemctl status mbot-microros-agent` | `active (running)` |
| Firmware talking to ROS | `ros2 node list`; `ros2 topic echo /odom --once` | `/mbot_control_node` is listed and `/odom` prints a message. The firmware also publishes `/imu`, `/encoders`, `/battery_adc` and `/motor_vel`, and listens on `/cmd_vel` |
| LIDAR connected | `ls -l /dev/ttyUSB0` | Device exists |
| ROS bridge | `systemctl status mbot_bridge_ros`; `ss -ltn \| grep 9090` | Running and listening on 9090 |
| Scratch | Open `http://<mbot-ip>:8602` | Scratch editor loads, with MBot blocks |
| Whole stack | `start_omni_stack.sh`, then open `http://<mbot-ip>:8000` | The map builds up as you drive |
