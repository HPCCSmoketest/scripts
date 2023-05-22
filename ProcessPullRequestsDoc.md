**Change on line 196**

Original:
```
print format % tuple([Msg]+map(str,Args))
```
Edit:
```
print(format % tuple([Msg]+list(map(str,Args))))
```
Suggestion: This edit should be fine as is.


