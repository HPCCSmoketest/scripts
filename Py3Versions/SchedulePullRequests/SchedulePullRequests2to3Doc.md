**Note:** All changes not presented here simply add an opening and closing parenthesis to a print statement when it already has one of each. It will be determined whether or not they are necessary.

**Change on line 180**

Original:
```
print format % tuple([Msg]+map(str,Args))
```
Edit:
```
print(format % tuple([Msg]+list(map(str,Args))))
```
Suggestion: This edit should be kept.
Update: This edit was kept.

**Change on line 1576, 2078**

Original:
```
if type(result) != type(u' '):
```
Edit:
```
if type(result) != type(' '):
```
Suggestion: The u in type is for unicode, so if it is intended to be in unicode regardless then the edit can stay.
Update: This edit was not kept

**Change on line 1787, 1791, 1795, 1832, 1837, 1841, 1859, 1862**

Original:
```
print str(e)+"(line: "+str(inspect.stack()[0][2])+")"
```
Edit:
```
print(str(e)+"(line: "+str(inspect.stack()[0][2])+")")
```
Suggestion: This edit should be kept.
Update: This edit was kept.

**Change on lines 3357-3361**

Original:
```
        result = u'Build: failed \xc2\xae\n'
        result += "Error(s): 7\n"
        result += u"/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:595:27: error: expected initializer before ‘-’ token\n"
        result += u"/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:596:13: error: ‘fileSize’ was not declared in this scope\n"
        result += u"/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:606:5: error: control reaches end of non-void function [-Werror=return-type]\n"
```
Edit:
```
        result = 'Build: failed \xc2\xae\n'
        result += "Error(s): 7\n"
        result += "/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:595:27: error: expected initializer before ‘-’ token\n"
        result += "/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:596:13: error: ‘fileSize’ was not declared in this scope\n"
        result += "/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:606:5: error: control reaches end of non-void function [-Werror=return-type]\n"
```
Suggestion: The u in type is for unicode, so if it is intended to be in unicode regardless then the edit can stay.
Update: This edit was kept.

**Change on line 3384, 3414, 3439, 3448**

Original:
```
msg= u'Automated Smoketest \n  \xe2\x80\x98 Test \xe2\x80\x99 \n'
```
Edit:
```
msg= 'Automated Smoketest \n  \xe2\x80\x98 Test \xe2\x80\x99 \n'
```
Suggestion: The u in type is for unicode, so if it is intended to be in unicode regardless then the edit can stay.
Update: This edit was kept.

**Change on line 3571-3574**

Original:
```
print "Exception in user code:"
print '-'*60
traceback.print_exc(file=sys.stdout)
print '-'*60
```
Edit:
```
print("Exception in user code:")
print('-'*60)
traceback.print_exc(file=sys.stdout)
print('-'*60)
```
Suggestion: This edit should be kept.
Update: This edit was kept.

##POST 2to3 CHANGES

**Issue on line 3425**

Original:
```
result += "+ jshint@2.9.4\N"
```

Error Message: "SyntaxError: (unicode error) 'unicodeescape' codec can't decode bytes in position 14-15: malformed \N character escape"

Current Fix:
```
result += "+ jshint@2.9.4\n"
```

**Issue on line 3435**

Original:
```
result += "Makefiles created (2019-02-28_09-07-19 45 sec )\N"
```

Error Message: "SyntaxError: (unicode error) 'unicodeescape' codec can't decode bytes in position 47-48: malformed \N character escape"

Current Fix:
```
result += "Makefiles created (2019-02-28_09-07-19 45 sec )\n"
```

**Issue on line 128**

Original:
```
sysId = platform.dist()[0] + ' ' + platform.dist()[1] + ' (' + platform.system() + ' ' + platform.release() + ')'
```

Error Message:
"AttributeError: module 'platform' has no attribute 'dist'"

Current Fix:
```
sysId = platform.uname()[0] + ' ' + platform.uname()[1] + ' (' + platform.system() + ' ' + platform.release() + ')'
```

**Issue on line 135**

Original:
```
sysId += '\n GCC:  ' + myProc.stdout.read().rstrip('\n')
```

Error Message:
"TypeError: a bytes-like object is required, not 'str'"

Current Fix:
```
sysId += '\n GCC:  ' + myProc.stdout.read().decode('utf-8').rstrip('\n')
```

The issue on line 135 is present on every other line until line 145. The addition of decode('utf-8') is added as well to each.

**Issue on line 3489**

Original:
```
print("Average Session Time                               : " + str(averageSessionTime) + " hours"
```

Error Message: TypeError: unsupported operand type(s) for +: 'NoneType' and 'str'

Current Fix:
```
print("Average Session Time                               : " + str(averageSessionTime) + " hours")
```

**Issue on line 3493**

Original:
```
if testPrNo > 0:
```

Error Message: TypeError: '>' not supported between instances of 'str' and 'int'

Current Fix:
```
if testPrNo > 0:
```

**formatResult() & How it is Called Changes**

Additions to formatResult():
```
	stdout = stdout.decode('utf-8')
	stderr = stderr.decode('utf-8')
```

Original:
```
	return (result, retcode)
```

Updated:
```
	return (result, retcode, stdout, stderr)
```

Original:
```
        (myStdout,  myStderr) = myProc.communicate()
        result = "returncode:" + str(myProc.returncode) + ", stdout:'" + myStdout + "', stderr:'" + myStderr + "'."
        print("Result:"+result)
```
Updated:
```
        result = formatResult(myProc)
        print("Result: " + result[0])
```
