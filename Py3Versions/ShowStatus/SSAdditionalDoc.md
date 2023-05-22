##Comment Removals

Lines 13-14:
```
#importing libraries
	      #from bokeh.plotting import figure
```
	      
Lines 18-19:
```
#from bokeh.models.annotations import LabelSet
       #from bokeh.models import DatetimeTickFormatter, DaysTicker
```

Line 40:
```
#print("logfile:%s, " % (currLogFile )),
```

Line 89:
```
#print(result2a)
```

Lines 93-94:
```
#myProc2 = subprocess.Popen(["cat "+ logfiles[0] + " | egrep -i 'milestone' | tail -n 1 "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
              #result2 = (myProc2.stdout.read() + myProc2.stderr.read()).decode("utf-8")
```
              
Line 104:
```
#print("phase: %s" % (phase))
```

Lines 128-131:
```
#if len(logfiles2) == 3:
#                    logFile=logfiles2[2] # Yes, it is, use RelWithDebInfo_Regress_Thor_YYYY-MM-DD_hh-mm-ss.log
#                else:
#                     logFile = logfiles[0]
```

Line 236:
```
#dataTable.source.js_on_change('data', data_table_force_change)
```

Line 261:
```
#headerRow = row(divTimeHeader, divUpdateHeader, divCurrentStateHeader)
```
