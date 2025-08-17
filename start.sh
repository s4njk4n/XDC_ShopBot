#!/bin/bash

nohup ./bot.sh > bot_output.log 2>&1 &
nohup ./monitor.sh > monitor_output.log 2>&1 &

echo ""
echo "XDC ShopBot - Telegram Bot Started (bot.sh)"
echo "XDC Shopbot - Blockchain Payment Monitor Started (monitor.sh)"
echo ""
