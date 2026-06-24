#!/bin/bash

caffeinate -i &
caffeinate_pid=$!
# Trap SIGINT (CTRL+C) and kill the caffeinate process before exiting
trap "kill $caffeinate_pid; echo 'dev.sh process killed'; exit" SIGINT

while true;
do
    # https://gist.github.com/jfortin42/68a1fcbf7738a1819eb4b2eef298f4f8
    # 113 = F15
    osascript -e 'tell application "System Events" to key code 113'
    sleep 59 # seconds
done
