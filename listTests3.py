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
from bokeh.models.widgets import DataTable,  TableColumn, Div, StringFormatter, HTMLTemplateFormatter #,Select, CheckboxGroup
from bokeh.layouts import column, row

import subprocess
import time
from datetime import datetime,  timedelta
#import re
#import os
#import glob
import platform

source = ColumnDataSource(data = dict())
updateInterval = 30 # sec
updateCounter = 0
tests = {}
isReported = False
statusColor = "blue"
# Force to write out smoketest report,
# True to report from the first time when a PR test started
isForceToReport = True

def update():
    global isReported, statusColor, updateCounter, isForceToReport
    counts = {'NumberOfTests' : 0, 'NumberOfClosed' : 0, 'NumberOfFinished' : 0, 'NumberOfRunning' : 0, 'NumberOfPassed' : 0, 'NumberOfFailed' : 0}

    updateCounter += 1
    startTimestamp = time.time()
    nextUpdateTime = datetime.now() + timedelta(seconds = updateInterval)
    print("Update (%s)..." % (time.strftime("%Y-%m-%d %H:%M:%S"))) 
    divUpdate.text = "Update..."
    myProc = subprocess.Popen(["ps aux | egrep -c  '[p]ython ./Schedule' "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
    smoketestIsUp = myProc.stdout.read().strip() + myProc.stderr.read().strip()
    smoketestIsUp = smoketestIsUp.decode("utf-8")
    
    if smoketestIsUp == '0':
        divCurrentState.text = 'Stopped'
        statusColor = "red"
    else:
        divCurrentState.text = 'Running'
        if isReported:
            # Smoketest stopped and result reported, but it is up again (restarted). 
            # Enable to report results after the next stop.
            isReported = False
            print("Result report re-enabled.")
            statusColor = "blue"
    # Force to report in every second update (actually in minute)
    if (updateCounter % 2) == 0:
        isForceToReport = True

#    currLogFile = "prp-" + time.strftime("%Y-%m-%d") + ".log"
    testDay = time.strftime("%y-%m-%d")
    divCurrentDay.text = testDay
    #print("logfile:%s, " % (currLogFile )),
    myProc = subprocess.Popen(["find OldPrs/PR-*/ PR-*/ -iname 'instance-*-*-" + testDay + "_*.info' -print | sort  --field-separator='-' --key=1,1 --key=4,4 --key=8.4n,8 --key=9n,9 "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
    #myProc = subprocess.Popen(["./showSchedulerStatus.sh " + currLogFile + "| egrep '\-{3} PR'"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
    files = myProc.stdout.read() + myProc.stderr.read()
    files = files.decode("utf-8").splitlines()
        
    print("\tlen files: %d" % (len(files)))
    prs = []
    prIds = []
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
    urls = []

    if len(files) > 0:
        index = 0
        for f in files:
            if len(f) > 0:
                print("File:%s" % (f))
                #myProcA = subprocess.Popen(["cat " + f + " | egrep -i 'Instance name|instanceName= |Commit Id|commitId= |Instance Id|base= |jira= ' | cut -d' ' -f5 | tr -d \\' | paste -d, -s - | cut -d',' -f1,2,3 --output ',' "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                myProcA = subprocess.Popen(["cat " + f + " | egrep -i 'Instance name|instanceName= |Commit Id|commitId= |Instance Id|base= |jira= |Bokeh address:' | cut -d' ' -f5 | tr -d \\' | paste -d, -s - "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)

                resultA = myProcA.stdout.read() + myProcA.stderr.read()
                items = resultA.decode("utf-8").strip().split(',')
                print(items)
                pr = 'N/A'
                prId = 'N/A'
                instance = 'N/A'
                commit = 'N/A'
                status = 'scheduled'
                result = 'N/A'
                start = 'N/A'
                end = 'N/A'
                ellaps = 'N/A'
                base = 'N/A'
                jira = 'N/A'
                url = 'N/A'

                for item in items:
                    item = item.strip()

                    itemIsHexString = False
                    # Check whether it is a hexadecmal string (commit id)
                    try:
                        i = int(item, 16)
                        itemIsHexString = True
                    except ValueError:
                        pass

                    if item.startswith('PR-'):
                        if pr == 'N/A':
                            pr = item
                            prId = pr.replace('PR-','')
                    elif item.startswith('i-'):
                        instance = item
                    elif item.upper().startswith('HPCC') or item.startswith('JIRA-'):
                        jira = item
                        if item.startswith('JIRA-'):
                            jira = item.replace('JIRA-','').replace('_',' ') + " (no ID)"
                    elif item.startswith('master') or item.startswith('candidate'):
                        base = item
                    elif itemIsHexString:
                        commit = item
                        if len(commit) > 0 and 'N/A' != commit:
                            status = 'running'
                    elif item.startswith('ec2-') or item.startswith('10.22.254'):
                        if url == 'N/A':
                            url = 'http://' + item
                    else:
                        print("Unknown item: '%s'" % (item))
                
                counts['NumberOfTests'] += 1
                if 'OldPr' in f:
                    status = 'closed'
                    counts['NumberOfClosed'] += 1
                else:
                    myProcB = subprocess.Popen(["egrep -i -c 'Terminate:' " + f ],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                    resultB = myProcB.stdout.read() + myProcB.stderr.read()
                    if int(resultB) > 0:
                        status = 'finished'
                        counts['NumberOfFinished'] += 1
                    else:
                        myProcC = subprocess.Popen(["egrep -i -c 'Instance is terminated, exit|MyExit' " + f ],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                        resultC = myProcC.stdout.read() + myProcC.stderr.read()
                        if int(resultC) > 0:
                            status = 'aborted'
                            counts['NumberOfFinished'] += 1
                if status != 'running':
                    myProcC = subprocess.Popen(["tail -n 1 " + f + " |  cut -d: -f1,2,3 "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                    resultC = myProcC.stdout.read() + myProcC.stderr.read()
                    end = resultC.strip().decode("utf-8")


                myProcC = subprocess.Popen(["head -n 1 " + f + " |  cut -d: -f1,2,3 "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                resultC = myProcC.stdout.read() + myProcC.stderr.read()
                start = resultC.strip().decode("utf-8")

                print("\tstart:%s, end: %s" % (start, end))

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
                tests[pr][instance]['bokehUrl'] = url
                if url == 'N/A' or status != 'running':
                    tests[pr][instance]['bokehUrlValid'] = False
                    url = None
                else:
                    tests[pr][instance]['bokehUrlValid'] = True

                index += 1

                #result.append("%s, %s, %s, %s" % (pr, commit, instance, status))
                prs.append(pr)
                prIds.append(prId)
                instances.append(instance)
                scheduledCommits.append(commit)
                testedCommits.append('N/A')
                statuses.append(status)
                results.append(result)
                starts.append(start)
                ends.append(end)
                if status == 'running':
                    e = int(startTimestamp - tests[pr][instance]['startTimestamp'])
                else:
                    e = (datetime.strptime(end, "%Y-%m-%d %H:%M:%S") -  datetime.strptime(start, "%Y-%m-%d %H:%M:%S")).total_seconds()
                #ellapses.append("%d sec" % ( e ))
                ellapses.append("%d sec (%s)" % (e, time.strftime("%H:%M:%S", time.gmtime(e))))
                bases.append(base)
                jiras.append(jira)
                urls.append(url)
    
        # get the results
        myProcRes = subprocess.Popen(["find OldPrs/PR-*/ PR-*/ -iname 'result-'" + testDay + "'*.log' -type f  -print | sort "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
        resFiles = myProcRes.stdout.read() + myProcRes.stderr.read()
        resFiles = resFiles.decode("utf-8").splitlines()
        
        print("\tlen result files: %d" % (len(resFiles)))

        if len(resFiles) > 0:
            index = 0
            for rf in resFiles:
                if len(rf) > 0:
                    print(rf)
                    myProcD = subprocess.Popen(["egrep '\s+Process PR-|\s+sha\s+:|\s+title\s*:|\s+base\s+:|\s+instance\s+:|\s+Summary\s+:|\s+pass :|In PR-' " + rf + " | tr -d '\t' | tr -s ' ' | paste -d, -s - | sed -e 's/ : /: /' -e 's/,(\s*)/, /g' -e 's/In PR-[0-9]* , label: [a-zA-Z0-9]* : //g' -e 's/^[0-9]*\/[0-9]*\.\s//g' | sed -r 's/(.*) ((sha: \w{8,8})([a-zA-Z0-9]+)), (.*)/\1 \3, \5/'"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                    resultD = myProcD.stdout.read() + myProcD.stderr.read()
                    items = resultD.decode("utf-8").split(',')
                    #print(items)
                    rPr = 'N/A'
                    rCommit = 'N/A'
                    rEllaps = 'N/A'
                    rResult = 'N/A'
                    rInstance  = 'N/A'
                    rTitle = 'N/A'
                    rBase = 'N/A'
                    end = ''

                    for i in items:
                        if 'Process PR' in i:  # The title can hold a text 'Process '
                            rPr = i.replace('Process','').strip()
                        elif 'sha' in i:
                            rCommit = i.replace('sha:','').strip()[0:8].upper()
                        elif 'Summary' in i:
                            rEllaps = i.replace('Summary :', '').strip()
                        elif 'pass' in i:
                            rResult = i.replace('pass :', '').strip()
                            if 'True' == rResult:
                               rResult = 'Passed'
                               counts['NumberOfPassed'] += 1
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
                    resultE = (myProcE.stdout.read() + myProcE.stderr.read()).decode('utf-8').strip()

                    
                    if len(resultE.strip()) > 0:
                        end = "20" + resultE.strip()

                    if rResult == 'N/A':
                        rResult = 'Failed'

                    print("\tend:%s (%d), result: %s" % (end, len(end), rResult))

                    #Update tests
                    if rInstance != 'N/A':
                        # We have PR and instance ID, we can update directly
                        try:
                            index = tests[rPr][rInstance]['index']
                            #print("\tindex: %d" % (index))
                            tests[rPr][rInstance]['testedCommit'] = rCommit
                            testedCommits[index] = rCommit
                            if len(end) > 0:
                            	tests[rPr][rInstance]['end'] = end
                            	ends[index] = end
                            
                            if rEllaps == 'N/A' or len(rEllaps) == 0:
                               e = (datetime.strptime(ends[index], "%Y-%m-%d %H:%M:%S") -  datetime.strptime(starts[index], "%Y-%m-%d %H:%M:%S")).total_seconds()
                               rEllaps = ("%d sec (%s)" % (e, time.strftime("%H:%M:%S", time.gmtime(e))))
                            print("\trEllaps: %s" % (rEllaps))

                            tests[rPr][rInstance]['ellaps'] = rEllaps 
                            ellapses[index] = rEllaps
                            tests[rPr][rInstance]['result'] = rResult
                            results[index] = rResult
                            if rResult != 'N/A' and statuses[index] == 'running':
                                statusses[index] = 'finished'

                            tests[rPr][rInstance]['title'] = rTitle
                            tests[rPr][rInstance]['base'] = rBase
                            tests[rPr][rInstance]['bokehUrlValid'] = False
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
                                if len(end) > 0:
                                    tests[rPr][rInstance]['end'] = end
                                    ends[index] = end

                                if rEllaps == 'N/A' or len(rEllaps) == 0:
                                    e = (datetime.strptime(ends[index], "%Y-%m-%d %H:%M:%S") -  datetime.strptime(starts[index], "%Y-%m-%d %H:%M:%S")).total_seconds()
                                    rEllaps = ("%d sec (%s)" % (e, time.strftime("%H:%M:%S", time.gmtime(e))))

                                tests[rPr][rInstance]['ellaps'] = rEllaps 
                                ellapses[index] = rEllaps
                                tests[rPr][rInstance]['result'] = rResult
                                results[index] = rResult

                                tests[rPr][rInstance]['title'] = rTitle
                                tests[rPr][rInstance]['base'] = rBase
                                tests[rPr][rInstance]['bokehUrlValid'] = False
                        except Exception as e:
                            print(e)
                        pass

        print(tests)
        counts['NumberOfRunning'] = counts['NumberOfTests'] - counts['NumberOfFinished'] - counts['NumberOfClosed']
        counts['NumberOfFailed']  = counts['NumberOfTests'] - counts['NumberOfPassed'] - counts['NumberOfRunning']
        print(counts)

        # Report smoketst result if Scheduler is stopped and not reported yet 
        # or if it is forced
        if (smoketestIsUp == '0' and not isReported) or (isForceToReport):
            # Smoketest stopped, but the results not (yet) reported
            print("Report the test results.")
            try:
                outFile = open("smoketestReport-" + testDay + ".log", "w")
                for i in range(len(prs)):
                    outFile.write("%d,%s,%s,%s,%s,%s,%s,tested as %s\n" % (i+1, prs[i], scheduledCommits[i], instances[i], statuses[i], results[i], ellapses[i].split()[0], testedCommits[i]))
                outFile.close()
            finally:
                print("\tDone")
                if isForceToReport:
                    isForceToReport = False
                else:
                    isReported = True    
    else:
        print("\tlen prs: %d" % (len(prs)))
        if len(prs) == 0:
            prs.append("")
            prIds.append("")
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
            urls.append("")

        prs[0] = "No test (yet)"
        
    #result.reverse()
    divTestCount.text = "%d" % (counts['NumberOfTests'])
    divClosedTestCount.text = "%d" % (counts['NumberOfClosed'])
    divFinishedTestCount.text = "%d" % (counts['NumberOfFinished'])
    divPassedTestCount.text = "%d" % (counts['NumberOfPassed'])
    divFailedTestCount.text = "%d" % (counts['NumberOfFailed'])
    divRunningTestCount.text = "%d" % (counts['NumberOfRunning'])
    
    source.data = {
        'pr' : prs,
        'prId' : prIds,
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
        'url'    : urls,

    }

        
    print(" Done (%2d sec, updateCounter:%d, smoketestIsUp:%s, isForceToReport:%s)." % (time.time()-startTimestamp, updateCounter, str(smoketestIsUp) ,str(isForceToReport) ))
    
    divUpdate.text = "Updated. (Next: %s)" % (nextUpdateTime.time().strftime("%H:%M:%S"))

print(platform.python_version_tuple())

conditionalUrlFormatterTemplatee="""
<div a <%=
    (function colorfromint(){
        if(url == ''){
            return("style=\"color:black\"")}
        else{return("style=\"color:blue\"")}
        }()) %>; 
      > 
<%= value %></div>
"""

conditionalUrlFormatterTemplatee = '''
<a href="<%= 
    (function ize(){
       if(url == ''){
          return(void(0))}
       else{ return(url)} 
     }()) %>;
    /showStatus" target="_blank"><%= value '%></a>' >; "
</div> 
'''
conditionalUrlFormatterTemplatee="""
<div style="color: <%=
    (function colorfromint(){
        if(url == ''){
            return("black")}
        else{return("blue")}
        }()) %>; 
      "> 
<%= value %></div>
"""
conditionalUrlFormatterTemplate = '''
<a href="<%= url %>/showStatus" target="_blank"><%= value %></a>
'''
columns = [
    #TableColumn(field='pr', title= 'PR', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='pr', title= 'PR', width=75, formatter=HTMLTemplateFormatter(template = '<a href="https://github.com/hpcc-systems/HPCC-Platform/pull/<%= prId %>" target="_blank"><%= value %></a>')),
    #TableColumn(field='instance', title= 'Instance', formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='instance', title= 'Instance',width=140, formatter=HTMLTemplateFormatter(template=conditionalUrlFormatterTemplate)),
    TableColumn(field='base', title= 'Base branch',width=120, formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='jira', title= 'Jira',width=120, formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='scheduledCommit', title= 'Scheduled commit', width=100, formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='testedCommit', title= 'Tested commit', width=100, formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='start', title= 'Start', width=140, formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='end', title= 'End', width=140, formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='ellaps', title= 'Ellaps time', width=140, formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='status', title= 'Status', width=80, formatter=StringFormatter(text_align='center',  text_color='#000000')),
    TableColumn(field='result', title= 'Result', width=80, formatter=StringFormatter(text_align='center',  text_color='#000000')),
    ]
    
dataTable = DataTable(source=source,  columns=columns,  width=1300, autosize_mode='none' )

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

divTestCountHeader = Div(text="Number of tests: ", width=100, height=15)
divTestCount = Div(text=" ", width=50, height=20)
divClosedTestCountHeader = Div(text="Number of closed: ", width=120, height=15)
divClosedTestCount = Div(text=" ", width=50, height=20)
divFinishedTestCountHeader = Div(text="Number of finished: ", width=150, height=15)
divFinishedTestCount = Div(text=" ", width=50, height=20)
divPassedTestCountHeader = Div(text="Number of passed: ", width=120, height=15)
divPassedTestCount = Div(text=" ", width=50, height=20)
divFailedTestCountHeader = Div(text="Number of failed: ", width=120, height=15)
divFailedTestCount = Div(text=" ", width=50, height=20)
divRunningTestCountHeader = Div(text="Number of running: ", width=120, height=15)
divRunningTestCount = Div(text=" ", width=50, height=20)
def update_time():
    divTime.text = time.strftime("%H:%M:%S")

phase = 0;
def update_status():
    global phase
    if phase == 0:
        divCurrentState.style = {"color":statusColor,"font-style":"bold", "font-weight":"bold"}
        if divRunningTestCount.text != '0':
            divRunningTestCount.style = {"font-style":"bold", "font-weight":"bold", "font-size":"125%"}
        if divFailedTestCount .text != '0':
            divFailedTestCount.style = {"color":"red", "font-style":"bold", "font-weight":"bold", "font-size":"125%"}
    else:
        divCurrentState.style = {"color":statusColor}
        divRunningTestCount.style = {}
        divFailedTestCount.style = {"color":"black"}
    phase = (phase + 1) % 2 
#headerRow = row(divTimeHeader, divUpdateHeader, divCurrentStateHeader)
staRow1 = row(divCurrentDayHeader, divCurrentDay, divTimeHeader, divTime, divUpdateHeader, divUpdate, divCurrentStateHeader, divCurrentState)
staRow2 = row(divTestCountHeader , divTestCount, divClosedTestCountHeader, divClosedTestCount, divFinishedTestCountHeader, divFinishedTestCount, divPassedTestCountHeader, divPassedTestCount, divFailedTestCountHeader, divFailedTestCount, divRunningTestCountHeader, divRunningTestCount )
#staRow3 = row(divCurrentEctHeader, divCurrentEct, divCurrentPhaseHeader, divCurrentPhase)
#curdoc().add_root(column(staRow1, staRow2, staRow3, dataTable))
curdoc().add_root(column(staRow1, staRow2, dataTable))

curdoc().title = "List tests"

curdoc().add_periodic_callback(update, updateInterval * 1000)

curdoc().add_periodic_callback(update_time, 1000)
curdoc().add_periodic_callback(update_status, 500)
update()
