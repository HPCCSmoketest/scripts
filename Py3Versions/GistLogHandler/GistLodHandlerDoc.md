**Change on line 36**

Original:
```
print format % tuple([Msg]+map(str,Args))
```
Edit:
```
print(format % tuple([Msg]+list(map(str,Args))))
```
Suggestion: This edit should be kept.

**Change on line 38**

Original:
```
print(format % tuple([Msg]+list(map(str,Args))))
```
Edit:
```
self.resultFile.write(format % tuple([Msg]+list(map(str,Args))))
```
Suggestion: This edit should be kept.

**Change on line 243**

Original:
```
print("Tracefilenames:"),
```
Edit:
```
print(("Tracefilenames:"), end=' ')
```
Suggestion: This edit should be kept as a comma does not keep future prints on the same line, unlike Python 2.

**Change on line 257**

Original:
```
print(("\tresult:"+result[0] + "\n"))
```
Edit:
```
print(("\tresult:"+result[0] + "\n"))
```
Suggestion: This change is not necessary.

**Change on line 414**

Original:
```
print("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
```
Edit:
```
print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))
```
Suggestion: This change is not necessary.

##Post 2to3 Changes

**Change on line 21**

Original:
```
self.resultFile = open(resultFileName,  "w", 0)
```
Error Message: "self.resultFile = open(resultFileName,  "w", 0)
ValueError: can't have unbuffered text I/O"

Suggestion: 
```
self.resultFile = open(resultFileName,  "w")
```

**Change on line 120**

Original:
```
for line in result[0].split('\n'):
```
Error Message: "IndexError: string index out of range"

Suggestion: Adding ```.decode('utf-8')``` on lines 43 & 46 fixed this issue 

