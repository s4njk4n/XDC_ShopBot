#!/bin/bash

# Handle bot.sh processes
bot_pids=$(ps aux | grep '[b]ot.sh' | awk '{print $2}')
if [ -n "$bot_pids" ]; then
  kill $bot_pids
  echo "Killed bot.sh processes:"
  echo "$bot_pids"
  echo ""
else
  echo "No bot.sh processes were active"
  echo ""
fi

# Handle monitor.sh processes
monitor_pids=$(ps aux | grep '[m]onitor.sh' | awk '{print $2}')
if [ -n "$monitor_pids" ]; then
  kill $monitor_pids
  echo "Killed monitor.sh processes:"
  echo "$monitor_pids"
  echo ""
else
  echo "No monitor.sh processes were active"
  echo ""
fi

# Show there are no remaining processes
echo "The only remaining processes are as follows (If all processes have been killed it is normal to see entries related to grep):"
ps aux | grep bot.sh
ps aux | grep monitor.sh
