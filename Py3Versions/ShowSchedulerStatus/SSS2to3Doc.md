**Change on line 36**

Original: 
```
print("Update (%s)..." % (time.strftime("%Y-%m-%d %H:%M:%S"))) 
```
Edit:
```
print("Update (%s)..." % (time.strftime("%Y-%m-%d %H:%M:%S"))) 
```
Suggestion: This change is not necessary.

**Update on line 56**

Original:
```
print("\tlastMsg: %s \n\tindex of lastMsg: %d" % (lastMsg,  lastMsgIndex))
```
Edit:
```
print(("\tlastMsg: %s \n\tindex of lastMsg: %d" % (lastMsg,  lastMsgIndex)))
```
Suggestion: This change is not necessary.

**Update on line 97**

Original:
```
print("PR logfile:%s, " % (logfiles[0])),
```
Edit:
```
print(("PR logfile:%s, " % (logfiles[0])), end=' ')
```
Suggestion: This change is needed due to how Python 3 uses the end parameter.

**Update on line 176**

Original:
```
print ("%s is overrun with %s seconds" % (pr, remainTime))
```
Edit:
```
print(("%s is overrun with %s seconds" % (pr, remainTime)))
```
Suggestion: This change is not necessary.

**Update on line 183**

Original:
```
print("\tIndex overflow: %d/%d." % (index, len(result))), 
```
Edit:
```
print(("\tIndex overflow: %d/%d." % (index, len(result))), end=' ') 
```
Suggestion: This change is needed due to how Python 3 uses the end parameter.

**Update on line 192**

Original:
```
print("\tlen result: %d" % (len(result)))
```
Edit:
```
print(("\tlen result: %d" % (len(result))))
```
Suggestion: This change is not necessary.

**Update on line 209**

Original:
```
print(" Done (%2d sec)." % (time.time()-startTimestamp))
```
Edit:
```
print((" Done (%2d sec)." % (time.time()-startTimestamp)))
```
Suggestion: This change is not necessary.

##Post 2-3 Changes:

**Issue on line 43**

Original:
```
result = result.split('\n')
```
Error Message: "a bytes-like object is required, not 'str'"

Suggested Fix:
```
result = result.decode('utf-8').split('\n')
```

