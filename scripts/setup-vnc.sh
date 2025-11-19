#!/bin/sh
x11vnc -storepasswd "${VNC_PASSWORD:-kvm}" /home/kvmuser/.vnc/passwd
