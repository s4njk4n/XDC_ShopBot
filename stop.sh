#!/bin/bash

kill $(ps aux | grep -E 'bot.sh|monitor.sh' | grep -v grep | awk '{print $2}')
sleep 2
ps aux | grep bot.sh
ps aux | grep monitor.sh
