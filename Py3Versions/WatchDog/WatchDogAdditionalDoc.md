##Comment Removals

Line 3:
```
#import os
```

Line 187:
```
#selfName = os.path.basename(sys.argv[0])
```

Lines 201-202:
```
#psCmd = "sudo ps aux | grep '["+process[0]+"]"+process[2:]+"'"
#psCmd += " | awk '{print $2 \",\" $12}' "
```
	        
Line 205:
```
#psCmd += " | awk '{print $1 \",\" $5}' "
```

