#!/bin/bash

#nvidia-smi -i 0 -pl 180
xinit `which nvidia-settings` -a [gpu:0]/GPUFanControlState=1 -a [fan:0]/GPUTargetFanSpeed=$1 -a [fan:1]/GPUTargetFanSpeed=$1 -- :0 -once
