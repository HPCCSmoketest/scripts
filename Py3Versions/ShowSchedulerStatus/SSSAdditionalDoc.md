##Comment Removals

Lines 11-12:
```
#importing libraries
	      #from bokeh.plotting import figure
```
	     
Lines 16-17:
```
#from bokeh.models.annotations import LabelSet
	      #from bokeh.models import DatetimeTickFormatter, DaysTicker
```
	      
Lines 39-40:
```
#print("logfile:%s, " % (currLogFile )),
	      #myProc = subprocess.Popen(["tail -n 1000 "+ currLogFile+ " |  grep -zoP 'Start: (?![\s\S]*Start: )[\s\S]*\z' | egrep -v 'Build|Number|No |Add|^$' | egrep '\-{3} PR'"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
```
	         
Line 45:
```
#print("\tlen result: %d" % (len(result)))
```

Line 109:
```
#print("phase: %s" % (phase))
```

Line 226:
```
#dataTable.source.js_on_change('data', data_table_force_change)
```

Line 251:
```
#headerRow = row(divTimeHeader, divUpdateHeader, divCurrentStateHeader)
```

