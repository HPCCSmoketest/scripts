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
    bases = []
    jiras = []

    if len(files) > 0:
        index = 0
        for f in files:
            if len(f) > 0:
                print("File:%s" % (f))
	        #myProcA = subprocess.Popen(["cat " + f + " | egrep -i 'Instance name|instanceName= |Commit Id|commitId= |Instance Id|base= |jira= ' | cut -d' ' -f5 | tr -d \\' | paste -d, -s - | cut -d',' -f1,2,3 --output ',' "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
	        myProcA = subprocess.Popen(["cat " + f + " | egrep -i 'Instance name|instanceName= |Commit Id|commitId= |Instance Id|base= |jira= ' | cut -d' ' -f5 | tr -d \\' | paste -d, -s - "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)

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
                base = 'N/A'
                jira = 'N/A'

                for item in items:
                    item = item.strip()

                    itemIsHexString = False
                    # Check whether it is a hexadecmal string (commit id)
		    try:
                        i = int(item, 16)
                        itemIsHexString = True
                    except ValueError:
                        pass

                    if item.startswith('PR-') and pr == 'N/A':
                        pr = item
                    elif item.startswith('i-'):
                        instance = item
                    elif item.startswith('HPCC-') or item.startswith('PR-wo-'):
                        jira = item
                    elif item.startswith('master') or item.startswith('candidate'):
			base = item
                    elif itemIsHexString:
                        commit = item
			if len(commit) > 0 and 'N/A' != commit:
                            status = 'running'
                    else:
                        print("Unknown item: '%s'" % (item))
                
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

                tests[pr][instance]['jira'] = jira
                tests[pr][instance]['base'] = base

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
                bases.append(base)
                jiras.append(jira)        
	
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
                    myProcD = subprocess.Popen(["egrep '\s+Process PR-|\s+sha\s+:|\s+title\s*:|\s+base\s+:|\s+instance\s+:|\s+Summary\s+:|\s+pass :|In PR-' " + rf + " | tr -d '\t' | tr -s ' ' | paste -d, -s - | sed -e 's/ : /: /' -e 's/,(\s*)/, /g' -e 's/In PR-[0-9]* , label: [a-zA-Z0-9]* : //g' -e 's/^[0-9]*\/[0-9]*\.\s//g' | sed -r 's/(.*) ((sha: \w{8,8})([a-zA-Z0-9]+)), (.*)/\1 \3, \5/'"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                    resultD = myProcD.stdout.read() + myProcD.stderr.read()
                    items = resultD.split(',')
                    #print(items)
                    rPr = 'N/A'
                    rCommit = 'N/A'
                    rEllaps = 'N/A'
                    rResult = 'N/A'
                    rInstance  = 'N/A'
                    rTitle = 'N/A'
                    rBase = 'N/A'

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
                        elif 'title:' in i:
                            rTitle = i.replace('title :','').strip()
                        elif 'base :' in i:
                            rBase = i.replace('base :', '').strip()

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

                            tests[rPr][rInstance]['title'] = rTitle
                            tests[rPr][rInstance]['base'] = rBase
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

                                tests[rPr][rInstance]['title'] = rTitle
                                tests[rPr][rInstance]['base'] = rBase

                        except Exception as e:
                            print(e)
                        pass

        print(tests)

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
            bases.append("")
            jiras.append("")

        prs[0] = "No test (yet)"
        
    #result.reverse()
    
    source.data = {
        'pr' : prs,
        'instance' : instances,
        'base' : bases,
        'jira' : jiras,
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
    TableColumn(field='base', title= 'Base branch', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='jira', title= 'Jira', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='scheduledCommit', title= 'Scheduled commit', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='testedCommit', title= 'Tested commit', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='start', title= 'Start', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='end', title= 'End', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='ellaps', title= 'Ellaps time', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='status', title= 'Status', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='result', title= 'Result', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    ]
    
dataTable = DataTable(source=source,  columns=columns,  width=1300 )

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
