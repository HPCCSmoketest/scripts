##2to3 Changes

**Note:** All changes not presented here simply add an opening and closing parenthesis to a print statement when it already has one of each. It will be determined whether or not they are necessary.

**Change on line 196**

Original:
```
print format % tuple([Msg]+map(str,Args))
```
Edit:
```
print(format % tuple([Msg]+list(map(str,Args))))
```
Suggestion: This edit should be kept.
Update: Followed edit


**Changes from lines 1214-1219**

Original:
```
print("\tResult: "+result)
                               
    if newlyClosedPrs == 0:
        print("No PR closed from last run.")
    else:
        print(str(newlyClosedPrs) +" PR(s) are closed and moved to OldPrs directory")
```
Edit:
```
print(("\tResult: "+result))
                               
    if newlyClosedPrs == 0:
        print("No PR closed from last run.")
    else:
        print((str(newlyClosedPrs) +" PR(s) are closed and moved to OldPrs directory"))
```
Suggestion: Only one of the last two print statements has an extra parentheses, should be adjusted to where both have either one or two.
Update: Followed original

**Change on line 1514, 2036**

Original:
```
if type(result) != type(u' '):
```
Edit:
```
if type(result) != type(' '):
```
Suggestion: the u in type is for unicode, so if it is intended to be in unicode regardless then the edit can stay.
Update: Followed edit

**Change on line 1733, 1737, 1741, 1786, 1791, 1795, 1813, 1816**

Original:
```
print str(e)+"(line: "+str(inspect.stack()[0][2])+")"
```
Edit:
```
print(str(e)+"(line: "+str(inspect.stack()[0][2])+")")
```
Suggestion: This edit should be kept.
Update: Followed edit

**Changes from line 2802-2806**

Original:
```
        result = u'Build: failed \n' # '\xc2\xae\n'
        result += "Error(s): 7\n"
        result += u"/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:595:27: error: expected initializer before ‘-’ token\n"
        result += u"/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:596:13: error: ‘fileSize’ was not declared in this scope\n"
        result += u"/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:606:5: error: control reaches end of non-void function [-Werror=return-type]\n"
```
Edit:
```
        result = 'Build: failed \n' # '\xc2\xae\n'
        result += "Error(s): 7\n"
        result += "/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:595:27: error: expected initializer before ‘-’ token\n"
        result += "/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:596:13: error: ‘fileSize’ was not declared in this scope\n"
        result += "/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:606:5: error: control reaches end of non-void function [-Werror=return-type]\n"
```
Suggestion: The removed u's represent unicode, will be determined if the original conversion is necessary.
Update: Followed edit

**Change on lines 2829, 2859, 2884, 2893**

Original:
```
msg= u'Automated Smoketest \n ' #'  \xe2\x80\x98 Test \xe2\x80\x99 \n'
```
Edit:
```
msg= 'Automated Smoketest \n ' #'  \xe2\x80\x98 Test \xe2\x80\x99 \n'
```
Suggestion: The removed u represent unicode, will be determined if the original conversion is necessary.
Update: Followed edit

**Change on line 3004-3007**

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
Update: Followed edit


##POST 2to3 CHANGES

**Issue on line 135**

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

**Issue on line 142**

Original:
```
sysId += '\n Host: ' + myProc.stdout.read().rstrip('\n')
```

Error Message:
"TypeError: a bytes-like object is required, not 'str'"

Current Fix:
```
sysId += '\n Host: ' + myProc.stdout.read().decode('utf-8').rstrip('\n')
```

The issue on line 142 is present on every other line until line 160. The addition of decode('utf-8') is added as well to each.

**Issue on like 148**

This may not be a Python3 issue. 

Original:
```
myProc = subprocess.Popen(["cmake --version"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
sysId += ',  CMake: ' + myProc.stdout.read().decode('utf-8').rstrip('\n').split()[2]
```

The length of .split() is 0, meaning that what Popen opens is likely empty.

Update: This issue was fixed by installing cmake.

**Issue on line 2933**

Original:
```
print("Average Session Time                               : " + str(averageSessionTime) + " hours"
```

Error Message: TypeError: unsupported operand type(s) for +: 'NoneType' and 'str'

Current Fix:
```
print("Average Session Time                               : " + str(averageSessionTime) + " hours")
```

**Issue on line 2939**

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

Addition to formatResult():
```
	stdout = stdout.decode('utf-8')
	stderr = stderr.decode('utf-8')
```

Original:
```
        (myStdout,  myStderr) = myProc.communicate()
        result = "returncode:" + str(myProc.returncode) + ", stdout:'" + myStdout + "', stderr:'" + myStderr + "'."
        print("Result:"+result)
```
Updated Version:
```
        result = formatResult(myProc)
        print("Result: " + result[0])
```

**If-else change on line 1975**

Original:
```
    if type(msg) == type(' '):
        msg = unicodedata.normalize('NFKD', msg).encode('ascii','ignore').replace('\'','').replace('\\u', '\\\\u')
        msg = repr(msg)
    else:
        msg = repr(msg)
```

Updated Version:
```
    msg = unicodedata.normalize('NFKD', msg).encode('ascii','ignore').replace('\'','').replace('\\u', '\\\\u')
    msg = repr(msg)
```


