**Change on line 24**

Original:
```
print timestamp+": "+string
```
Edit:
```
print(timestamp+": "+string)
```
Suggestion: This change should be kept.

**Change on line 60**

Original:
```
print("Interrupted at " + time.asctime())
```
Edit:
```
print(("Interrupted at " + time.asctime()))
```
Suggestion: This change is not necessary.

##POST 2to3 CHANGES

Issue on line 14:

Original:
```
    from sets import Set 
```
Error Message: ModuleNotFoundError: No module named 'sets'

Fix: Remove the line since set() is built in

Change on line 105:

Original:
```
    killProcess = Set()
```

Fix:
```
    killProcess = set()
```
Reason: Python3 has a built in set function called set().

