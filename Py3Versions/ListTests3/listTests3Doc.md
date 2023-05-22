**Note**: All changes created on 2to3 were simply extra parenthesis added to print statements when they already had a set of them, making it unnecessary to keep in the finalized converted version.

**Comment Removals**

Line 14:
```
#from bokeh.plotting import figure
```

Lines 18-19:
```
#from bokeh.models.annotations import LabelSet
#from bokeh.models import DatetimeTickFormatter, DaysTicker
```

Lines 26-28:
```
#import re
#import os
#import glob
```
			  
Line 69:
```
#currLogFile = "prp-" + time.strftime("%Y-%m-%d") + ".log"
```

Line 72:
```
#print("logfile:%s, " % (currLogFile )),
```

Line 74:
```
#myProc = subprocess.Popen(["./showSchedulerStatus.sh " + currLogFile + "| egrep '\-{3} PR'"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
```

Line 98:
```
#myProcA = subprocess.Popen(["cat " + f + " | egrep -i 'Instance name|instanceName= |Commit Id|commitId= |Instance Id|base= |jira= ' | cut -d' ' -f5 | tr -d \\' | paste -d, -s - | cut -d',' -f1,2,3 --output ',' "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
```

Line 205:
```
#result.append("%s, %s, %s, %s" % (pr, commit, instance, status))
```

Line 219:
```
#ellapses.append("%d sec" % ( e ))
```

Line 240:
```
#print(items)
```

Line 271:
```
#print("rPR:%s, rInstance:%s, rCommit:%s, rEllaps:%s, rResult:%s" % (rPr, rInstance, rCommit, rEllaps, rResult))
```

Line 290, 327:
```
#print("\tindex: %d" % (index))
```

Line 321:
```
#print("\tinst: %s" % (inst))
```

Line 391:
```
#result.reverse()
```

Line 458:
```
#TableColumn(field='pr', title= 'PR', formatter=StringFormatter(text_align='center',  text_color='#000000')),
```

Line 460:
```
#TableColumn(field='instance', title= 'Instance', formatter=StringFormatter(text_align='center',  text_color='#000000')),
```

Line 481:
```
#dataTable.source.js_on_change('data', data_table_force_change)
```

Line 532:
```
#headerRow = row(divTimeHeader, divUpdateHeader, divCurrentStateHeader)
```

Lines 535-536:
```
#staRow3 = row(divCurrentEctHeader, divCurrentEct, divCurrentPhaseHeader, divCurrentPhase)
#curdoc().add_root(column(staRow1, staRow2, staRow3, dataTable))
```
