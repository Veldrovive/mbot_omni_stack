# System reference

This is what's on a working MBot Omni and where each piece comes from. The steps that install all of it are in [Setting up an MBot from scratch](setup-from-scratch.md).

## Services

| Service | What it does | Starts | Installed by |
| --- | --- | --- | --- |
| `mbot-start-network` | Reads `/boot/firmware/mbot_config.txt`. Sets the hostname, then joins the configured Wi-Fi or starts the `<hostname>-AP` hotspot (bot at `192.168.3.1`). Also starts the Pico, according to `autostart`. Runs once, as root. | On boot | mbot_sys_utils `install_mbot_ros_services.sh` |
| `mbot-oled` | Shows the hostname, IP, SSID and other diagnostics on the OLED. | On boot | mbot_sys_utils `install_mbot_ros_services.sh` |
| `mbot-microros-agent` | Runs the micro-ROS agent from `~/microros_ws` on `/dev/mbot_microros` at 115200 baud. It connects the firmware to ROS. | When udev sees `/dev/mbot_microros`. It's bound to that device, so it stops if the board is unplugged | mbot_sys_utils `install_mbot_ros_services.sh` and `udev_rules/install_rules.sh` |
| `mbot_bridge_ros` | Runs the rosbridge websocket server on port 9090 (`services/start_bridge.sh`). | On boot | `mbot_bridge_ros/services/install_ros_bridge_service.sh` |
| `mbot-scratch-gui` | Serves `/data/www/scratch` on port 8602 using `serve` under Node 22. | On boot | `scratch-editor-mbot/services/install_service.sh` |
| `mbot_omni_stack` *(optional)* | Runs `scripts/start_omni_stack.sh`: a tmux session called `mbot_omni` with bringup, SLAM and the web app dev server. It skips the bridge if port 9090 is already taken. | On boot, if installed | `services/install_omni_stack_service.sh` |

Check any of them with `systemctl status <name>`, and read their logs with `journalctl -u <name> -f`.

## Ports

| Port | What |
| --- | --- |
| 9090 | rosbridge websocket. `mbot_js`, the web app and Scratch all connect here |
| 8000 | Web app (Vite dev server, or `vite preview`) |
| 8602 | Scratch editor |

## Devices

| Device | What | Set up by |
| --- | --- | --- |
| `/dev/mbot_microros` | The Pico's micro-ROS serial channel, used by the agent | udev rule `/etc/udev/rules.d/99-ros-mbot.rules`, matched on the USB interface name "MBot MicroROS Data" |
| `/dev/mbot_debug` | The Pico's debug and printf console. View it with `minicom -D /dev/mbot_debug` | Same udev rule ("MBot Debug Console") |
| `/dev/ttyUSB0` | RPLIDAR A1. The default port in `sllidar_a1_launch.py` | The same udev rule makes all `ttyUSB*` and `ttyACM*` devices world-readable and writable |

## Environment (`~/.bashrc`)

| Line | Added by |
| --- | --- |
| `export PICO_SDK_PATH=/home/mbot/pico-sdk` | mbot_sys_utils `install_mbot_dependencies.sh` |
| `source /opt/ros/jazzy/setup.bash` | mbot_sys_utils `install_ros2_jazzy.sh` |
| `export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` | mbot_sys_utils `install_ros2_jazzy.sh` |
| `export PICO_TOOLCHAIN_PATH=/usr/bin/` | mbot_sys_utils `install_microros.sh` |
| `source /home/mbot/microros_ws/install/local_setup.sh` | mbot_sys_utils `install_microros.sh` |
| nvm loader lines | nvm installer |
| `source /home/mbot/mbot_omni_stack/mbot_ros2_ws/install/local_setup.bash` | Added by hand ([setup part 6](setup-from-scratch.md#6-build-the-ros-2-workspace)) |

systemd services don't read `~/.bashrc`. Each service sources what it needs itself, so `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` doesn't apply to the agent or the bridge. With several bots on one network, check that one bot's bridge can't see another bot's topics.

## Files outside this repository

| Path | What | From |
| --- | --- | --- |
| `/boot/firmware/mbot_config.txt` | Per-bot hostname, hotspot password, Wi-Fi and Pico autostart setting | Template in mbot_sys_utils, then edited by hand |
| `/usr/local/bin/mbot-upload-firmware` | Flashes `.uf2` files to the Pico over GPIO and USB | mbot_sys_utils `install_mbot_dependencies.sh` |
| `/usr/local/bin/picotool` | Pico tool | mbot_sys_utils `install_mbot_dependencies.sh` |
| `/usr/local/etc/mbot_start_networking.sh`, `/usr/local/etc/mbot_ros_oled_display.py` | Scripts the networking and OLED services run | mbot_sys_utils `install_mbot_ros_services.sh` |
| `/usr/local/bin/mbot-scratch-gui-start` | Script the Scratch service runs | `scratch-editor-mbot/services/install_service.sh` |
| `/data/www/scratch` | Built Scratch site | `scratch-editor-mbot/install_scripts/install.sh` |
| `~/pico-sdk` | Raspberry Pi Pico SDK | mbot_sys_utils `install_mbot_dependencies.sh` |
| `~/microros_ws` | micro-ROS agent workspace | mbot_sys_utils `install_microros.sh` |
| `/usr/local/lib/aarch64-linux-gnu/libcamera*` | libcamera and rpicam-apps, built from source | mbot_sys_utils `install_camera.sh` |

## Copies of `mbot_bridge_ros`

There are three copies of the bridge repository:

| Copy | Used by |
| --- | --- |
| `mbot_bridge_ros/` | The bridge service and `npm run test:bridge` |
| `mbot_web_app_ros/mbot_bridge_ros/` | The web app's `mbot_js` dependency |
| `scratch-editor-mbot/packages/mbot_bridge_ros/` | Scratch's `mbot_js` dependency |

When you change the bridge, push the change once, move all three copies to that commit, and rebuild `mbot_js` in each (`npm run build` in `mbot_js/`). Then commit the new submodule pointers, innermost repository first.

## Before you wipe a bot

These things exist only on the SD card. Save them first:

- **`/boot/firmware/mbot_config.txt`.** It holds Wi-Fi and hotspot passwords, so store it somewhere private, not in this repository.
- **Saved maps** in `mbot_ros2_ws/mbot_navigation/maps/`. That folder is in the upstream `mbot-project/mbot_ros2_ws` submodule, so maps saved there can't be pushed.
- **Uncommitted or unpushed changes** in any submodule. Check from the repository root:
  ```bash
  git status
  git submodule foreach --recursive 'git status --short; git log --oneline @{u}.. 2>/dev/null'
  ```
- **Personal setup:** `~/.ssh`, `~/.gitconfig`, GitHub credentials and editor settings.
- **UMich Wi-Fi enrolment.** Re-run the SecureW2 installer after rebuilding.

You don't need to save the Pico firmware or its calibration. Both are stored on the Pico.

## Known issues

- **Wrong robot model.** `mbot_bringup.launch.py` loads `mbot_classic.urdf.xacro`, because there is no Omni URDF yet. The robot model, TF frames and footprint are the Classic's.
- **Bridge port when started from tmux.** `start_omni_stack.sh` launches rosbridge without a port, so it relies on rosbridge's default of 9090. The systemd service passes `port:=9090` explicitly. If `rosbridge_suite`'s defaults are edited locally, a bridge started from tmux will listen on the wrong port.
