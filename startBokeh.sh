#!/bin/bash

logFile="bokeh-"$(date "+%Y-%m-%d")".log";

exec >> ${logFile} 2>&1

echo "Kill bokeh..."

sudo pkill bokeh

echo "Done."

echo "Restart bokeh"

unbuffer bokeh serve showStatus.py --allow-websocket-origin=10.241.40.11:5006

# On ONT-011 we can use hostname
#unbuffer bokeh serve showStatus.py --allow-websocket-origin=$(hostname):5006


