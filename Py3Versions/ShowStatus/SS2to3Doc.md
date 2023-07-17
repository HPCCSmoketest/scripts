**Change on line 36**

Original:
```
print("Update (%s)..." % (time.strftime("%Y-%m-%d %H:%M:%S"))), 
```
Edit:
```
print(("Update (%s)..." % (time.strftime("%Y-%m-%d %H:%M:%S"))), end=' ') 
```
Suggestion: Remove the unnecessary extra parenthesis, keep the end=.

**Change on line 85**

Original:
```
print("PR logfile:%s, " % (logfiles[0])),
```
Edit:
```
print(("PR logfile:%s, " % (logfiles[0])), end=' ')
```
Suggestion: Remove the unnecessary extra parenthesis, keep the end=.

**Change on line 195**

Original:
```
print ("%s is overrun with %s seconds" % (pr, remainTime))
```
Edit:
```
print(("%s is overrun with %s seconds" % (pr, remainTime)))
```
Suggestion: This change is not necessary.

**Change on line 202**

Original:
```
print("Index overflow: %d/%d." % (index, len(result)-1)), 
```
Edit:
```
print(("Index overflow: %d/%d." % (index, len(result)-1)), end=' ') 
```
Suggestion: Remove the unnecessary extra parenthesis, keep the end=.

**Change on line 220**

Original:
```
print(" Done (%2d sec)." % (time.time()-startTimestamp))
```
Edit:
```
print((" Done (%2d sec)." % (time.time()-startTimestamp)))
```
Suggestion: This change is not necessary.

