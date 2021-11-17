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
tests = {}

def update():
    startTimestamp = time.time()
    nextUpdateTime = datetime.now() + timedelta(seconds = updateInterval)
    print("Update (%s)..." % (time.strftime("%Y-%m-%d %H:%M:%S"))) 
    divUpdate.text = "Update..."
    divCurrentState.text = 'Idle'

    currLogFile = "prp-" + time.strftime("%Y-%m-%d") + ".log"
    testDay = time.strftime("%y-%m-%d")
    divCurrentDay.text = testDay
    #print("logfile:%s, " % (currLogFile )),
    myProc = subprocess.Popen(["find OldPrs/PR-*/ PR-*/ -iname 'instance-*-*-" + testDay + "_*.info' -print | sort  --field-separator='-' --key=1,1 --key=4,4 --key=8.4n,8 --key=9n,9 "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
    #myProc = subprocess.Popen(["./showSchedulerStatus.sh " + currLogFile + "| egrep '\-{3} PR'"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
    files = myProc.stdout.read() + myProc.stderr.read()
    files = files.splitlines()
        
    print("\tlen files: %d" % (len(files)))
    prs = []
    instances = []
    scheduledCommits = []
    testedCommits = []
    statuses = []
    results = []
    starts = []
    ends = []
    ellapses = []

    if len(files) > 0:
        index = 0
        for f in files:
            if len(f) > 0:
                print("File:%s" % (f))
	        myProcA = subprocess.Popen(["cat " + f + " | egrep -i 'Instance name|instanceName= |Commit Id|commitId= |Instance Id' | cut -d' ' -f5 | tr -d \\' | paste -d, -s - | cut -d',' -f1,2,3 --output ',' "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                resultA = myProcA.stdout.read() + myProcA.stderr.read()
		items = resultA.split(',')
                print(items)
                pr = 'N/A'
                instance = 'N/A'
                commit = 'N/A'
                status = 'scheduled'
                result = 'N/A'
                start = 'N/A'
                end = 'N/A'
                ellaps = 'N/A'
                for item in items:
                    if item.startswith('PR-'):
                        pr = item.strip()
                    elif item.startswith('i-'):
                        instance = item.strip()
                    else:
                        commit = item.strip()
                        # Check whether it is a hexadecmal string (commit id)
			try:
                      	    i = int(commit, 16)
                        except ValueError:
                            commit = 'N/A'
			if len(commit) > 0 and 'N/A' != commit:
                            status = 'running'

                
		if 'OldPr' in f:
                    status = 'closed'
                else:
                    myProcB = subprocess.Popen(["egrep -i -c 'Terminate:' " + f ],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                    resultB = myProcB.stdout.read() + myProcB.stderr.read()
                    if int(resultB) > 0:
                        status = 'finished'

                myProcC = subprocess.Popen(["head -n 1 " + f + " |  cut -d: -f1,2,3 "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                resultC = myProcC.stdout.read() + myProcC.stderr.read()
                start = resultC.strip()

	        #print("\t%s" % (resultA))
                if pr not in tests:
                    tests[pr] = {}
                if instance not in tests[pr]:
                    tests[pr][instance] = {}

                tests[pr][instance]['scheduledCommit'] = commit
                tests[pr][instance]['testedCommit'] = 'N/A'
                tests[pr][instance]['status'] = status
                tests[pr][instance]['result'] = result
                tests[pr][instance]['start'] = start
                tests[pr][instance]['end'] = end
                tests[pr][instance]['ellaps'] = ellaps
                tests[pr][instance]['index'] = index
                if 'startTimestamp' not in tests[pr][instance]:
                    tests[pr][instance]['startTimestamp'] = time.mktime(time.strptime(start, "%Y-%m-%d %H:%M:%S")) #startTimestamp 
		index += 1

                #result.append("%s, %s, %s, %s" % (pr, commit, instance, status))
                prs.append(pr)
                instances.append(instance)
                scheduledCommits.append(commit)
                testedCommits.append('N/A')
                statuses.append(status)
                results.append(result)
		starts.append(start)
                ends.append(end)
                e = int(startTimestamp - tests[pr][instance]['startTimestamp'])
                #ellapses.append("%d sec" % ( e ))
                ellapses.append("%d sec (%s)" % (e, time.strftime("%H:%M:%S", time.gmtime(e))))
        
	
	# get the results
        myProcRes = subprocess.Popen(["find OldPrs/PR-*/ PR-*/ -iname 'result-'" + testDay + "'*.log' -type f  -print | sort "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
        resFiles = myProcRes.stdout.read() + myProcRes.stderr.read()
        resFiles = resFiles.splitlines()
        
        print("\tlen result files: %d" % (len(resFiles)))

        if len(resFiles) > 0:
            index = 0
            for rf in resFiles:
                if len(rf) > 0:
                    print(rf)
                    myProcD = subprocess.Popen(["egrep '\s+Process PR-|\s+sha\s+:|\s+instance\s+:|\s+Summary\s+:|\s+pass :|In PR-' " + rf + " | tr -d '\t' | tr -s ' ' | paste -d, -s - | sed -e 's/ : /: /' -e 's/,(\s*)/, /g' -e 's/In PR-[0-9]* , label: [a-zA-Z0-9]* : //g' -e 's/^[0-9]*\/[0-9]*\.\s//g' | sed -r 's/(.*) ((sha: \w{8,8})([a-zA-Z0-9]+)), (.*)/\1 \3, \5/'"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                    resultD = myProcD.stdout.read() + myProcD.stderr.read()
                    items = resultD.split(',')
                    #print(items)
                    rPr = 'N/A'
                    rCommit = 'N/A'
                    rEllaps = 'N/A'
                    rResult = 'N/A'
                    rInstance  = 'N/A'

                    for i in items:
                        if 'Process' in i:
                            rPr = i.replace('Process','').strip()
                        elif 'sha' in i:
                            rCommit = i.replace('sha:','').strip()[0:8].upper()
                        elif 'Summary' in i:
                            rEllaps = i.replace('Summary :', '').strip()
                        elif 'pass' in i:
                            rResult = i.replace('pass :', '').strip()
                            if 'True' == rResult:
                               rResult = 'Passed'
                            else:
                               rResult = 'Failed' 
                        elif 'instance :' in i:
                            rInstance = i.replace('instance :', '').strip() 

                    #print("rPR:%s, rInstance:%s, rCommit:%s, rEllaps:%s, rResult:%s" % (rPr, rInstance, rCommit, rEllaps, rResult))
        	
                    myProcE = subprocess.Popen(["egrep 'Finished:' " + rf + " | tr -d '\t' | cut -d ' ' -f 2,3 | tr -d ',' | tr -d '\n' "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                    resultE = myProcE.stdout.read() + myProcE.stderr.read()
                    end = resultE.strip()
                    #print("\tend:%s" % (end))

                    #Update tests
                    if rInstance != 'N/A':
                        # We have PR and instance ID, we can update directly
                        try:
                            index = tests[rPr][rInstance]['index']
                            #print("\tindex: %d" % (index))
                            tests[rPr][rInstance]['testedCommit'] = rCommit
                            testedCommits[index] = rCommit
                            tests[rPr][rInstance]['end'] = end
                            ends[index] = end
                            tests[rPr][rInstance]['ellaps'] = rEllaps 
                            ellapses[index] = rEllaps
                            tests[rPr][rInstance]['result'] = rResult
                            results[index] = rResult
                        except Exception as e:
                            print(e)
                            pass
                        pass
                    else:
                        # We have PR but not instance ID, find it
                        try:
                            index = -1
                            for inst in tests[rPr]:
                                #print("\tinst: %s" % (inst))
                                if rCommit == tests[rPr][inst]['scheduledCommit']:
                                    index = tests[rPr][inst]['index']
                                    rInstance = inst
                                    break
                                        
                            #print("\tindex: %d" % (index))
                            if index != -1:
				tests[rPr][rInstance]['testedCommit'] = rCommit
                                testedCommits[index] = rCommit
                                tests[rPr][rInstance]['end'] = end
                                ends[index] = end
                                tests[rPr][rInstance]['ellaps'] = rEllaps 
                                ellapses[index] = rEllaps
                                tests[rPr][rInstance]['result'] = rResult
                                results[index] = rResult

                        except Exception as e:
                            print(e)
                        pass

        print(tests)

        '''
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
                                        prefix = ["E: ", ", T: "]
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
        '''
    else:
        print("\tlen prs: %d" % (len(prs)))
        if len(prs) == 0:
            prs.append("")
            instances.append("")
            scheduledCommits.append("")
            testedCommits.append("")
            statuses.append("")
            results.append("")
            starts.append("") 
            ends.append("")
            ellapses.append("")

        prs[0] = "No test"
        
    #result.reverse()
    
    source.data = {
        'pr' : prs,
        'instance' : instances,
        'scheduledCommit' : scheduledCommits,
        'testedCommit' : testedCommits,
        'status' : statuses,
        'result' : results,
        'start'  : starts,
        'end'    : ends,
        'ellaps' : ellapses,

    }
        
    # Select the last row in the table
    #sel = Selection( indices = [len(result)-2, len(result)-1])
    #sel = Selection( indices = [len(result)-1])
    #source.selected = sel
        
    print(" Done (%2d sec)." % (time.time()-startTimestamp))
    
    divUpdate.text = "Updated. (Next: %s)" % (nextUpdateTime.time().strftime("%H:%M:%S"))

columns = [
    TableColumn(field='pr', title= 'PR', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='instance', title= 'Instance', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='scheduledCommit', title= 'Scheduled commit', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='testedCommit', title= 'Tested commit', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='start', title= 'Start', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='end', title= 'End', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='ellaps', title= 'Ellaps time', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='status', title= 'Status', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='result', title= 'Result', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    ]
    
dataTable = DataTable(source=source,  columns=columns,  width=1100)

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

divCurrentDayHeader = Div(text="Test day:", width=60, height=15)
divCurrentDay = Div(text=" ", width=100, height=20)

divCurrentUserHeader = Div(text="User: ", width=50, height=15)
divCurrentUser = Div(text=" ", width=100, height=20)

divCurrentEctHeader = Div(text="ECT:", width=50, height=15)
divCurrentEct = Div(text=" ", width=150, height=20)

divCurrentPhaseHeader = Div(text="Phase: ", width=50, height=15)
divCurrentPhase = Div(text=" ", width=350, height=20)

def update_time():
    divTime.text = time.strftime("%H:%M:%S")

#headerRow = row(divTimeHeader, divUpdateHeader, divCurrentStateHeader)
staRow1 = row(divCurrentDayHeader, divCurrentDay, divTimeHeader, divTime, divUpdateHeader, divUpdate, divCurrentStateHeader, divCurrentState)
staRow2 = row(divCurrentUserHeader, divCurrentUser)
staRow3 = row(divCurrentEctHeader, divCurrentEct, divCurrentPhaseHeader, divCurrentPhase)
curdoc().add_root(column(staRow1, staRow2, staRow3, dataTable))

curdoc().title = "List tests"

curdoc().add_periodic_callback(update, updateInterval * 1000)

curdoc().add_periodic_callback(update_time, 1000)
update()
