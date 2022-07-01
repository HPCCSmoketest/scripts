#!/bin/bash

logFile="bokeh-"$(date "+%Y-%m-%d")".log";

exec >> ${logFile} 2>&1

echo "Kill bokeh..."

sudo pkill bokeh

echo "Done."

echo "Restart bokeh"

BOKEH=$(which "bokeh")
echo "Bokeh: $BOKEH"

PYTHON_MAIN_VERSION=$( ${BOKEH} info | egrep '^Python' | awk '{ print $4 }' | cut -d. -f1)
echo "Python main version: $PYTHON_MAIN_VERSION"
if [[ ${PYTHON_MAIN_VERSION} -eq 3 ]]
then
    PYTHON_APPS="listTests3.py showStatus.py"
else
    PYTHON_APPS="showStatus.py showSchedulerStatus.py listTests.py"
fi

echo "Python apps: $PYTHON_APPS"

unbuffer ${BOKEH} serve ${PYTHON_APPS} \
   --allow-websocket-origin=hpcc-platform-dev-el7-dailybuild.novalocal:5006 \
   --allow-websocket-origin=10.224.20.54:5006

# On ONT-011 we can use hostname
#unbuffer bokeh serve ${PYTHON_APPS} --allow-websocket-origin=$(hostname):5006


