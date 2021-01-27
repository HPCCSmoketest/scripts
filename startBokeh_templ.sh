#!/bin/bash

logFile="bokeh-"$(date "+%Y-%m-%d")".log";

exec >> ${logFile} 2>&1

echo "Kill bokeh..."

sudo pkill bokeh

echo "Done."

echo "Restart bokeh"

#unbuffer 
$( which "bokeh") serve showStatus.py --allow-websocket-origin=ec2-15-222-244-18.ca-central-1.compute.amazonaws.com:5006 --allow-websocket-origin=15.222.244.18:5006 

# On ONT-011 we can use hostname
#unbuffer bokeh serve showStatus.py --allow-websocket-origin=$(hostname):5006


