#!/bin/bash

# MBot Omni Stack Service Installation Script

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit
fi

SERVICE_FILE="mbot_omni_stack.service"
SERVICE_PATH="/etc/systemd/system/"

echo "Copying $SERVICE_FILE to $SERVICE_PATH..."
cp ./services/$SERVICE_FILE $SERVICE_PATH

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling and starting the service..."
systemctl enable mbot_omni_stack.service
systemctl start mbot_omni_stack.service

echo "Done! You can check the status with: systemctl status mbot_omni_stack.service"
