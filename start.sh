#!/bin/bash

nohup ./bot.sh > bot_output.log 2>&1 &
nohup ./monitor.sh > monitor_output.log 2>&1 &
