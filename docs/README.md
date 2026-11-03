# MBot Omni Stack Docs

These docs explain how to build an MBot Omni running this stack from a blank SD card, and what ends up on the robot once you have.

- [Setting up an MBot from scratch](setup-from-scratch.md): the full procedure, in order, from flashing the OS to checking the web app and Scratch work.
- [System reference](system-reference.md): every service, port, device name, environment variable and file location on a working bot, where each one comes from, and what to back up before you wipe a bot.

The top-level [README](../README.md) is the quick-start for building and running the stack on a bot that already has the base system. Use these docs when you're starting from nothing or need to know how the pieces fit together.

## What runs on an MBot

A finished bot has three layers. Each is installed from a different place.

| Layer | What it is | Installed from |
| --- | --- | --- |
| Pico firmware | micro-ROS firmware on the control board. It drives the motors and publishes odometry and IMU data. It's stored on the Pico's own flash, so wiping the SD card doesn't erase it. | [mbot_firmware_ros_omni](../mbot_firmware_ros_omni/README.md) |
| Base system | Ubuntu 24.04, ROS 2 Jazzy, the pico-sdk, libcamera, the micro-ROS agent, udev rules, and the networking and OLED services. | [mbot_sys_utils](https://github.com/mbot-project/mbot_sys_utils) (`ros2_mbot_sys_utils` folder) |
| Omni stack | The ROS 2 workspace (bringup, SLAM, Nav2), the rosbridge websocket server, the web app and the Scratch editor. | This repository and its submodules |

```
 Browser ── web app (:8000) ─┐
 Browser ── Scratch (:8602) ─┼─ websocket ─► rosbridge (:9090) ─┐
 mbot_js scripts ────────────┘                                  │ ROS 2
                                                                 ▼
          bringup (LIDAR, robot description) ◄──► SLAM Toolbox or Nav2
                                                                 ▲
                                                                 │ ROS 2
       Pico firmware ◄── USB serial /dev/mbot_microros ──► micro-ROS agent
```
