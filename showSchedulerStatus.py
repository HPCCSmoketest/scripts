#
# Start:
# bokeh serve showStatus.py (locally)
#
# bokeh serve showStatus.py --allow-websocket-origin=10.241.40.11:5006 (remotely)
#
# For pass and fail
#  suite=$( egrep -i 'suite:' RelWithDebInfo_Build_2020-06-02_13-27-25.log | tail -n 1 ); suite=${suite//\[Action\]/};  echo "$suite";  section=$( sed -rn "/$suite$/,/$suite$/p" RelWithDebInfo_Build_2020-06-02_13-27-25.log ); echo "$section" | egrep -i 'Queries: '; echo "$section" | egrep -i -c ' Pass ';  echo "$section" | egrep -i -c ' Fail ';
#



#importing libraries
#from bokeh.plotting import figure
from bokeh.models import ColumnDataSource,  Selection
from bokeh.io import curdoc
from bokeh.models.callbacks import CustomJS
#from bokeh.models.annotations import LabelSet
#from bokeh.models import DatetimeTickFormatter, DaysTicker
from bokeh.models.widgets import DataTable,  TableColumn, Div, StringFormatter #,Select, CheckboxGroup
from bokeh.layouts import column, row

import subprocess
import time
from datetime import datetime,  timedelta
import re
import os
import glob

source = ColumnDataSource(data = dict())
updateInterval = 30 # sec

def update():
    startTimestamp = time.time()
    nextUpdateTime = datetime.now() + timedelta(seconds = updateInterval)
    print("Update (%s)..." % (time.strftime("%Y-%m-%d %H:%M:%S"))) 
    divUpdate.text = "Update..."
    divCurrentState.text = 'Idle'

    currLogFile = "prp-" + time.strftime("%Y-%m-%d") + ".log"
    #print("logfile:%s, " % (currLogFile )),
    myProc = subprocess.Popen(["tail -n 1000 "+ currLogFile+ " |  grep -zoP 'Start: (?![\s\S]*Start: )[\s\S]*\z' | egrep -v 'Build|Number|No |Add|^$' | egrep '\-{3} PR'"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
    result = myProc.stdout.read() + myProc.stderr.read()
    result = result.split('\n')
        
    #print("\tlen result: %d" % (len(result)))

    if len(result) >= 2:

        lastMsgIndex = -1
        while len(result[lastMsgIndex]) == 0:
           lastMsgIndex -= 1

        lastMsg = result[lastMsgIndex]
        print("\tlastMsg: %s \n\tindex of lastMsg: %d" % (lastMsg,  lastMsgIndex))

        if lastMsg.startswith('Wait') or lastMsg.startswith('start'): 
            divCurrentState.text = 'Idle'
        elif lastMsg.startswith('Done, exit'):
            divCurrentState.text = 'Stopped'
        elif lastMsg.startswith('--- PR'):
            divCurrentState.text = "Busy"

        index = lastMsgIndex 
        pr = "none"
        user = "none"
        startTimeStr = ""
        phase = "N/A"
        subPhase = ""
        ect = "N/A"
        try:
            while (index > -10):
                line = result[index].strip()
                if line.startswith('end'):
                    break
                    
                if line.lower().startswith('user'):
                    user = line.split(':')[1]

                if line.lower().startswith('start:'):
                    startTimeStr = line.split(':', 1)[1].strip()
                    startTime = datetime.strptime(startTimeStr, "%y-%m-%d  %H:%M:%S" )
                                  
                m = re.match('^([0-9]*)/([0-9]*)\. Process of (PR-[0-9]*)(.*)', line)
                if m:
                    pr = m.group(3)
                    # Check the PR directory and process build log file is it is exists
                    if  os.path.exists(pr):
                        # if we have multiple build/test file use the latest.
                        logfiles = sorted(glob.glob(pr + '/*_Build_*.log'), reverse = True)
                        if len(logfiles) > 0:
                            # Check the logfile is relevant or not
                            logFileTimeStr = logfiles[0].split('_', 2)[2].replace('.log', '').strip()
                            logFileTime = datetime.strptime(logFileTimeStr, "%Y-%m-%d_%H-%M-%S" )
                            if logFileTime >= startTime:
                                print("PR logfile:%s, " % (logfiles[0])),

                                myProc2 = subprocess.Popen(["cat "+ logfiles[0] + " | egrep -i 'milestone' | tail -n 1 "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                                result2 = myProc2.stdout.read() + myProc2.stderr.read()
                                if len(result2) > 0:
                                    items = result2.split(':', 1)
                                    if len(items) == 2:
                                        phase = items[1]
                                else:
                                    phase = "Not registered"
                                
                                #print("phase: %s" % (phase))
                                
                                if ('nstall' in phase) or ('uild' in phase):
                                    myProc3 = subprocess.Popen(["  egrep -i '\[[0-9 ]*\%\]' " + logfiles[0] + " | tail -n 1 "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                                    result3 = myProc3.stdout.read() + myProc3.stderr.read()
                                    if len(result3) > 0:
                                        result3Items = result3.replace('[', '').replace(']','') .split(' ',  2)
                                        
                                        if len(result3Items) >= 2:
                                                subPhase += result3Items[1]+ " "
                                    
                                elif 'egression' in phase:
                                    myProc3 = subprocess.Popen([" egrep -i -A1 'Suite:' " + logfiles[0] + " | tail -n 2 "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                                    result3 = myProc3.stdout.read() + myProc3.stderr.read()
                                    if len(result3) > 0:
                                        prefix = ["E: ", ", N: "]
                                        index = 0
                                        result3Items = result3.split('\n')
                                        for item in result3Items:
                                            items = item.split(':', 1)
                                            if len(items) == 2:
                                                subPhase += prefix[index] + items[1].strip()
                                                index += 1
                                        
                                        myProc4 = subprocess.Popen([" egrep -i  -i '\[Action\]' " + logfiles[0] + " | tail -n 1 "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                                        result4 = myProc4.stdout.read() + myProc4.stderr.read()
                                        if len(result4) > 0:
                                            result4Items = result4.split(' ',  4)
                                            if len(result4Items) >= 2:
                                                # There are leading spaces before the test number and the split() generates empty items from them
                                                # Should look for the first non empty
                                                index = 1
                                                while (result4Items[index] == ''):
                                                    index += 1
                                                subPhase += ", R: " + result4Items[index].strip('.') + " "
                                                
                                            else:
                                                subPhase += "0 "
                                                
                                        myProc5 = subprocess.Popen([" suite=$( egrep -i 'suite:' " + logfiles[0] + " | tail -n 1 ); suite=${suite//\[Action\]/};  section=$( sed -rn \"/$suite$/,/$suite$/p\" " + logfiles[0] + " ); echo \"$section\" | egrep -i -c ' Pass ';  echo \"$section\" | egrep -i -c ' Fail '; "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                                        result5 = myProc5.stdout.read() + myProc5.stderr.read()
                                        if len(result5) > 0:
                                            prefix = [", P: ", ", F: "]
                                            result5Items = result5.split()
                                            if len(result5Items) >= 1:
                                                for index in range(len(result5Items)):
                                                    subPhase += prefix[index] + result5Items[index].strip('.')
                                                
                                            else:
                                                subPhase += "/ - /-  "
                                        
                                if len(subPhase) > 0:
                                    subPhase = ' ( ' + subPhase + ') '
                                        
                    m2 = re.match('.* ~(.*) hour.*$', m.group(4))
                    if m2:
                        _ect = float(m2.group(1))
                        
                        ectTime = startTime + timedelta(hours = _ect)
                        now =  datetime.now()
                        isInTime = ''
                        isOver = ''
                        if ectTime >= now:
                            remainTime = (ectTime.hour * 3600 + ectTime.minute * 60 + ectTime.second) - (now.hour * 3600 + now.minute * 60 + now.second)
                            isInTime = '-'
                        else:
                            remainTime = (now.hour * 3600 + now.minute * 60 + now.second) - (ectTime.hour * 3600 + ectTime.minute * 60 + ectTime.second) 
                            isOver = 'overrun'
                            print ("%s is overrun with %s seconds" % (pr, remainTime))

                        remainTimeStr = "%s%2dh %2dm %s" % (isInTime, remainTime / 3600, (remainTime % 3600) / 60,  isOver)
                        ect = "~ %s (%s)" % (ectTime.strftime("%H:%M"), remainTimeStr )
                        break
                index -= 1
        except:
            print("\tIndex overflow: %d/%d." % (index, len(result))), 
            pass
        
        divCurrentPr.text = pr 
        divCurrentUser.text = user
        divCurrentEct.text = ect
        divCurrentPhase.text = phase + subPhase

    else:
        print("\tlen result: %d" % (len(result)))
        if len(result) == 0:
            result.append("")
        
        result[0] = "No active PR"
        
    result.reverse()
    
    source.data = {
        'msg' : result
    }
        
    # Select the last row in the table
    #sel = Selection( indices = [len(result)-2, len(result)-1])
    #sel = Selection( indices = [len(result)-1])
    #source.selected = sel
        
    print(" Done (%2d sec)." % (time.time()-startTimestamp))
    
    divUpdate.text = "Updated. (Next: %s)" % (nextUpdateTime.time().strftime("%H:%M:%S"))

columns = [
    TableColumn(field='msg', title= 'History', formatter=StringFormatter(text_align='right',  text_color='#000000')),
    ]
    
dataTable = DataTable(source=source,  columns=columns,  width=800)

# If no row(s) selected and dataTable 'data' changed then this scrolls down to the last lines.
data_table_force_change = CustomJS(args=dict(source=dataTable),  code="""
    source.change.emit()
    source.source.change.emit()
    """)

#dataTable.source.js_on_change('data', data_table_force_change)
divTimeHeader = Div(text = 'Smoketest time:',  width=100,  height = 15)
divTime = Div(text=time.strftime("%H:%M:%S"), width=80, height=20)

divUpdateHeader = Div(text='Refresh status', width=100, height=15)
divUpdate = Div(text=" ", width=200, height=20)

divCurrentStateHeader = Div(text="Status:", width=60, height=15)
divCurrentState = Div(text=" ", width=100, height=20)

divCurrentPrHeader = Div(text="Session:", width=100, height=15)
divCurrentPr = Div(text=" ", width=100, height=20)

divCurrentUserHeader = Div(text="User: ", width=50, height=15)
divCurrentUser = Div(text=" ", width=100, height=20)

divCurrentEctHeader = Div(text="ECT:", width=50, height=15)
divCurrentEct = Div(text=" ", width=150, height=20)

divCurrentPhaseHeader = Div(text="Phase: ", width=50, height=15)
divCurrentPhase = Div(text=" ", width=350, height=20)

def update_time():
    divTime.text = time.strftime("%H:%M:%S")

#headerRow = row(divTimeHeader, divUpdateHeader, divCurrentStateHeader)
staRow1 = row(divTimeHeader, divTime, divUpdateHeader, divUpdate, divCurrentStateHeader, divCurrentState)
staRow2 = row(divCurrentPrHeader, divCurrentPr, divCurrentUserHeader, divCurrentUser)
staRow3 = row(divCurrentEctHeader, divCurrentEct, divCurrentPhaseHeader, divCurrentPhase)
curdoc().add_root(column(staRow1, staRow2, staRow3, dataTable))

curdoc().title = "Smoketest Scheduler Status"

curdoc().add_periodic_callback(update, updateInterval * 1000)

curdoc().add_periodic_callback(update_time, 1000)
update()
