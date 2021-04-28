#!/usr/bin/python
# -*- coding: utf-8 -*-

import os
#import system
import json
import sys
import subprocess
import time
import glob
import re
import signal
import atexit
import unicodedata
import inspect
import traceback
import platform
import threading
import random

from operator import xor
from GistLogHandler import GistLogHandler

#For gracefully stop the smoketest
stopSmoketest = False
stopWait = False

testmode=False
# For override testmode setting
if ('testmode' in os.environ) and (os.environ['testmode'] == '1'):
    testmode=True

# From 2018-02-15 the default is True instead of False to avoid 
# rolling over problem with faulty merged/updated master
removeMasterAtExit=True
# For override removeMasterAtExit setting
if ('removeMasterAtExit' in os.environ) and (os.environ['removeMasterAtExit'] == '0'):
    removeMasterAtExit=False

enableShallowClone=False
# For override enableShallowClone setting
if ('enableShallowClone' in os.environ) and (os.environ['enableShallowClone'] == '1'):
    addGitComment=True
    
addGitComment=True
# For override addGitComment setting
if ('addGitComment' in os.environ) and (os.environ['addGitComment'] == '0'):
    addGitComment=False

runOnce=False
# For override runOnce setting
if ('runOnce' in os.environ) and (os.environ['runOnce'] == '1'):
    runOnce=True

keepFiles=False
# For override keepFiles setting
if ('keepFiles' in os.environ) and (os.environ['keepFiles'] == '1'):
    keepFiles=True

testOnlyOnePR = False
# For override testOnlyOnePR setting
if ('testOnlyOnePR' in os.environ) and (os.environ['testOnlyOnePR'] == '1'):
    testOnlyOnePR=True
    
testPrNo='0'
# For override testPrNo setting
if ('testPrNo' in os.environ) and (os.environ['testPrNo'] != '0'):
    testPrNo = os.environ['testPrNo']

# From 2018-02-15 the default is True instead of False
runFullRegression=True
# For override runFullRegression setting
if ('runFullRegression' in os.environ) and (os.environ['runFullRegression'] == '0'):
    runFullRegression = False

# Remove build and HPCC-Platform directories before execute build 
# (Not implemented yet!)
preCleanDirectories=False
# For override preCleanDirectories setting
if ('preCleanDirectories' in os.environ) and (os.environ['preCleanDirectories'] == '1'):
    preCleanDirectories = True
    
# Use quick build, whre we copy the generated binaries into a target directory structure instead of 
# create package and isntall it
useQuickBuild=False
# For override useQuickBuild setting
if ('useQuickBuild' in os.environ) and (os.environ['useQuickBuild'] == '1'):
    useQuickBuild = True

# Build ECLWatch or SKIP it
buildEclWatch=False
# For override buildEclWatch setting
if ('buildEclWatch' in os.environ) and (os.environ['buildEclWatch'] == '1'):
    buildEclWatch = True

# Build draft PR or skip it
# True -> Yes, skip it, 
# False -> no, handle it as a normal PR
skipDraftPr=True

# For override skipDraftPr setting
if ('skipDraftPr' in os.environ) and (os.environ['skipDraftPr'] == '0'):
    skipDraftPr = False

averageSessionTime=0.5
if ('AVERAGE_SESSION_TIME' in os.environ):
    averageSessionTime = float(os.environ['AVERAGE_SESSION_TIME'])

verbose = False
# Do not update PR source code - means use last PR code (Do not get new commit)
# It has sense if and only if there is a previously updated HPCC platform code with merged PR code
# Currently doesn't used
doNotUpdate = True

maxIdleTime = 180 # 600 # sec
noEcho = False
sysId = platform.dist()[0] + ' ' + platform.dist()[1] + ' (' + platform.system() + ' ' + platform.release() + ')'
appId = "App"""
gitHubToken=None

if 'inux' in sysId:
    myProc = subprocess.Popen(["gcc --version | head -n 1 "], shell=True,  bufsize=8192, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    sysId += '\n GCC:  ' + myProc.stdout.read().rstrip('\n')
    myProc = subprocess.Popen(["hostname"], shell=True, bufsize=8192, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    sysId += '\n Host: ' + myProc.stdout.read().rstrip('\n')
    myProc = subprocess.Popen(["git --version"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
    sysId += '\n Git:  ' + myProc.stdout.read().rstrip('\n')
    
    myProc = subprocess.Popen(['ps $PPID | tail -n 1 | awk "{print \$6}"'], shell=True, bufsize=8192, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    parentCommand = myProc.stdout.read().rstrip('\n')
    
    myProc = subprocess.Popen(['hostname'], shell=True, bufsize=8192, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    appId = myProc.stdout.read().rstrip('\n')

failEmoji=':x:'
passEmoji=':white_check_mark:'

#testInfo = {}
threads = {}
myPassw = 'Boglarka990405\n'

embededStuffTests = {
                            'Rembed':       ['testing/regress/ecl/embedR.ecl'], 
                            'cassandra':    ['testing/regress/ecl/cassandra-simple.ecl'], 
                            'javaembed':    ['testing/regress/ecl/embedjava-catch.ecl', 
                                                    'testing/regress/ecl/embedjava.ecl', 
                                                'testing/regress/ecl/javaimport.ecl'], 
                            'memcached':['testing/regress/ecl/memcachedtest.ecl'], 
                            'mysql':        ['testing/regress/ecl/mysqlembed.ecl'], 
                            'pyembed':    ['testing/regress/ecl/embedp2.ecl', 
                                                 'testing/regress/ecl/embedpy-catch.ecl', 
                                                 'testing/regress/ecl/embedpy.ecl', 
                                                 'testing/regress/ecl/pyimport.ecl', 
                                                 'testing/regress/ecl/streame2.ecl', 
                                                 'testing/regress/ecl/streame3.ecl', 
                                                 'testing/regress/ecl/streame.ecl'], 
                            'redis':       ['testing/regress/ecl/redislockingtest.ecl', 
                                                 'testing/regress/ecl/redissynctest.ecl'], 
                            'sqlite3':   ['testing/regress/ecl/sqlite.ecl'], 
                            'v8embed':   ['testing/regress/ecl/embedjs2.ecl', 
                                                 'testing/regress/ecl/embedjs-catch.ecl', 
                                                 'testing/regress/ecl/embedjs.ecl'], 
                            '_common':   ['testing/regress/ecl/streamread.ecl'], 
                            }

def myPrint(Msg, *Args):
        if verbose:
            format=''.join(['%s']*(len(Args)+1)) 
            print format % tuple([Msg]+map(str,Args))

def WildGen( testFiles):
    files = []
    #if testFiles[0].startswith('testing/regress/ecl/'):
    for testName in testFiles:
        if os.sep in testName:
            testName = os.path.basename(testName)
        files.append(testName)

    groups = {}
    groups['0'] = {'files': [],  'mask':'',  'maxlen': 9999}
    groups['0']['files'].append(files[0])
    
    for index in range(1, len(files)):
        # To avoid this kind of very "wild" results 'm*' os 's*' 
        # the first two character used to generate groups
        ch10 = (files[0][0])
        ch11 = (files[0][1])
        ch20 = (files[index][0])
        ch21 = (files[index][1])
        #print "ch10:'"+str(ch10)+"', ch11:'"+str(ch11)+"'"
        #print "ch20:'"+str(ch20)+"', ch21:'"+str(ch21)+"'"
        # With XOR separate the filenames started with different letter and it is generates a kind of
        # HASH value to separate filenames into clusters/groups
        val = xor(ord(ch10),  ord(ch20))*100 + xor(ord(ch11),  ord(ch21))
        #print(val)
        id = str(val)
        if str(val) not in groups:
            groups[id] =  {'files': [],  'mask':'',  'maxlen': 9999}
        groups[id]['files'].append(files[index])
        if len(files[index]) < groups[id]['maxlen']:
            groups[id]['maxlen'] = len(files[index])
    
    myPrint(groups)
    #print '\n\n'
    pass
    # If a group has only one element, then this element will be the mask
    # else we try to find the longest common starting string then add a '*' at its end and that will be the mask.
    # In this example it will be the 'childds*' 
    
    cmd = ''
    for group in groups:
        if len(groups[group]['files']) == 1:
            groups[group]['mask'] = groups[group]['files'][0]
        else:
            mask = ''
            for chid in range (0,  groups[group]['maxlen']):
                for index in range(1, len(groups[group]['files'])):
                    ch1 = (groups[group]['files'][0][chid])
                    ch2 = (groups[group]['files'][index][chid])
                    val = xor(ord(ch1),  ord(ch2))
                    if val != 0:
                        break
                if val == 0:
                    mask = mask + groups[group]['files'][0][chid]
                else:
                    break
            groups[group]['mask'] = mask + '*'
        cmd += groups[group]['mask'] +' '
    
    #print groups
    myPrint ("\n\n"+cmd+"\n")
    
    return cmd

def CollectResultsOld(logPath, tests):
    result = []
    prefixes = [ 'setup',  'test']
    targets = ['hthor',  'thor',  'roxie']
    logs = {'setup':{}, 'test':{}}
    if os.path.exists(logPath):
        curDir = os.getcwd()
        os.chdir( logPath ) 
        for prefix in prefixes:
            if 'test' == prefix:
                realPrefix = ''
                for testName in tests:
                    if os.sep in testName:
                        testName = os.path.basename(testName)
                    testName = testName.replace('.ecl', '')
                    logs[prefix][testName] = {}
            else:
                realPrefix = prefix+'_'
            for target in targets:
                files = glob.glob( realPrefix+target + \
                ".[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9].log" )
                if files: 
                    sortedFiles = sorted( files, key=str.lower, reverse=True )
                    logFileName = sortedFiles[0] 
                    print(logFileName)
                    
                    logFile = open(logFileName,  'rb')
                    oldIndex = 1
                    for line in logFile:
                        line = line.strip().replace('\n', '')
                        line = line.replace('.',':')
                        items = line.split(':')
                        if line.startswith('------------------------'):
                            break
                        if re.match("[0-9]+",  items[0]):
                            index=int(items[0])
                        else:
                            continue
                            
                        if len(items)  in range (4, 6):
                            # This is a 'Test:' line with ot without version
                            #testName = items[0]+'.'+items[2].strip()
                            testName = items[2].strip()
                            testNameLen = len(testName)
                            if testName not in logs[prefix]:
                                logs[prefix][testName] = {}
                            #logs[prefix][testName][target]
                        elif 'Fail' in line:
                            logs[prefix][testName][target]= 'Fail'
                        elif 'Pass' in line:
                            logs[prefix][testName][target]= 'Pass'
                            
        os.chdir( curDir ) 
         
        for prefix in prefixes:
            result.append("\\n| " + prefix + " | " + targets[0] + " | " + targets[1] + " | " + targets[2] + " |")
            result.append("| ----- | ----- | ----- | ---- |")
            for testname in sorted(logs[prefix],  key=str.lower) :
                #items = testname.split('.')
                #line = "%-*s " % (20,  items[1])
                line = "| "+ testname + " "
                
                for target in targets:
                    if target in logs[prefix][testname]:
                        line += "| " + logs[prefix][testname][target] + " "
                    else:
                        line += "| Excl. "
                        
                result.append(line + "|")    
             
            result.append(' ')
        pass
        
    return result  

def CollectResults(logPath, tests, prid=0, isGitHubComment=True):
    result = ''
    isCoreFlesReported = False
    prefixes = [ 'setup',  'test']
    targets = ['hthor',  'thor',  'roxie']
    logs = {'setup':{}, 'test':{}}
    elapsTimes = {}
    if os.path.exists(logPath):
        curDir = os.getcwd()
        os.chdir( logPath ) 
        for prefix in prefixes:
            if 'test' == prefix:
                realPrefix = ''
                for testName in tests:
                    if os.sep in testName:
                        testName = os.path.basename(testName)
                    testName = testName.replace('.ecl', '')
                    logs[prefix][testName] = {}
            else:
                realPrefix = prefix+'_'

            for target in targets:
                if prefix not in elapsTimes:
                    elapsTimes[prefix] = {}
                
                if target not in elapsTimes[prefix]:
                    elapsTimes[prefix][target] = 'N/A'
                                    
                files = glob.glob( realPrefix+target + \
                ".[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9].log" )
                if files: 
                    sortedFiles = sorted( files, key=str.lower, reverse=True )
                    logFileName = sortedFiles[0] 
                    print(logFileName)

                    logFile = open(logFileName,  'rb')
                    oldIndex = 1
                    errMsg=[]
                    inTests = True
                    inError = False

                    for line in logFile:
                        line = line.strip().replace('\n', '').replace("'", "")
                        if line.startswith('Queries:'):
                            # Check if no test case scheduled on this target
                            items = line.split(':')
                            numOfQueries = 0
                            if len(items) == 2:
                                numOfQueries = int(items[1])
                            if numOfQueries == 0:
                                break
                        if line.startswith('-----'):
                            inTests = False
                            inError = False
                        elif line.startswith('Error:'):
                            inError = True
                            continue
                        linetemp = line.replace('.',':')
                        items = linetemp.split(':')
                        if re.match("[0-9]+",  items[0]):
                            try:
                                index=int(items[0])
                            except:
                                print("Unexpected error:" + str(sys.exc_info()[0]) + " items[0]: '" + str(items[0]) + "' (line: " + str(inspect.stack()[0][2]) + ")" )
                                traceback.print_stack()
                                pass
                        elif line.startswith('Elapsed'):
                            m=re.match('^Elapsed time: (.*)$', line)
                            if m:
                                elapsTimes[prefix][target] = m.group(1)
                        elif not inError:
                            continue
                            
                        if index == 0 and not inError:
                            inError = True
                            continue

                        if ((len(items) == 4) or (len(items) >= 5)) and ('Test' in items[1]):
                            if len(errMsg) > 0:
                                try:
                                    # store errMsg into test case info
                                    logs[prefix][testName][target]['errMsg'] = errMsg
                                except:
                                    print("Unexpected error:" + str(sys.exc_info()[0]) + " items[0]: " + str(items[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
                                    traceback.print_stack()
                                    result += '\n'.join(errMsg)
                                    pass
                                errMsg = []
                                
                            # This is a 'Test:' line
                            #testName = items[0]+'.'+items[2].strip()
                            if 'version' in items[3]:
                                testName = items[2].strip() +' ('+''.join(items[4:]).strip().replace(' )', ')')
                                testNameLen = len(testName)
                            else:
                                testName = items[2].strip()
                                testNameLen = len(testName)
                            if testName not in logs[prefix]:
                                logs[prefix][testName] = {}
                            if target not in logs[prefix][testName]:
                                logs[prefix][testName][target] = { 'index' : -1, 'result':'',  'wuid':'', 'errMsg':'' }
                            elif inError:
                                # Add error msg
                                pass
                            #logs[prefix][testName][target]
                            
                            logs[prefix][testName][target]['index'] = index
                        elif '. Fail' in line:
                            logs[prefix][testName][target]['result'] ='Fail'
                            lineItems = line.split()
                            logs[prefix][testName][target]['wuid'] = 'No WUID'
                            for lineItem in lineItems:
                                if re.match("W20[0-9]+",  lineItem):
                                    logs[prefix][testName][target]['wuid'] = lineItem
                                    break
                            logs[prefix][testName][target]['errMsg'] = ''
                        elif '. Pass' in line:
                            logs[prefix][testName][target]['result'] = 'Pass'
                        elif inError:
                            if len(line) > 0:
                                errMsg.append(line)
                            else:
                                # zero length line at the end of error log
                                if len(errMsg):
                                    #inError=False
                                    pass
                                else:
                                    errMsg.append("no error info")
                                
                    if numOfQueries == 0:
                        continue

                    if logs[prefix][testName][target]['result'] == 'Fail':
                        if len(errMsg) > 0:
                            # store errMsg into test case info
                            logs[prefix][testName][target]['errMsg'] = errMsg
                            errMsg = []
                        else:
                            if len(errMsg):
                                inError=False
                            else:
                                logs[prefix][testName][target]['errMsg'] = 'No error info'

        os.chdir( curDir ) 

        if runFullRegression:
            # planned layout is:
            # 
            # |     phase     | total | pass | fail |
            # |---------------|-------|------|------|
            # | setup (hthor) |   87  |  86  |   1  |
            # ...
            # (Error list if found some)
            #
            errors = {}
            table = TableGenerator()
            for prefix in prefixes:
                for target in targets:
                    phaseName = prefix + ' (' + target + ')'
                    table.addItem('phase:'+phaseName)
                    executed = 0
                    passed = 0
                    failed = 0
                    #for testname in sorted(logs[prefix],  key=str.lower) :
                    for testname in sorted(logs[prefix],  key=str) :
                        if target in logs[prefix][testname]:
                            executed += 1
                            #print("%3d:%s-%s-%s" % (executed,  prefix,  target, testname))
                            if logs[prefix][testname][target]['result'] == 'Pass':
                                passed += 1
                            elif logs[prefix][testname][target]['result'] == 'Fail':
                                failed += 1

                                if prefix not in errors:
                                    errors[prefix] = {}
                                if target not in errors[prefix]:
                                    errors[prefix][target] = []
                                    
                                errorRecord = {}
                                errorRecord['index'] = str(logs[prefix][testname][target]['index'])
                                errorRecord['testname'] = testname
                                errorRecord['errormsg'] = logs[prefix][testname][target]['errMsg']
                                errorRecord['wuid'] = logs[prefix][testname][target]['wuid']
                                errors[prefix][target].append(errorRecord)
                            else:
                                pass
                        else:
                            pass
                        pass
                        
                    table.addItem('total:' + str(executed))
                    table.addItem('pass:' + str(passed))
                    table.addItem('fail:' + str(failed))
                    table.addItem('elaps#'+ elapsTimes[prefix][target], '#')
                    table.completteRow()
                    #print("total:%3d, pass: %3d, fails:%3d\n-----------------------\n" % (executed,  passed,  failed))
                pass
            result += table.getTable()

            if len(errors) > 0:
                try:
                    gistHandler = GistLogHandler(gitHubToken)
                    gistHandler.createGist(prid)
                    gistHandler.cloneGist()
                    gistHandler.updateReadme('OS: ' + sysId + '\n')
                    errorStr = '[Errors:](' + gistHandler.getGistUrl() + ')\n'
                    for prefix in sorted(errors,  key=str):
                        errorStr += '- ' + prefix+'\n' 
                        for target in targets:
                            if target in errors[prefix]:
                                errorStr += '  - ' + target+'\n' + '    - '
                                for error in errors[prefix][target]:
                                    (linkTag,  id) = gistHandler.gistAddError(error['testname'], error['errormsg'], error['wuid'])
                                    errorStr += error['index'] + '\. ' + linkTag + ', '
                                  
                                errorStr += '\n'
                    gistHandler.updateReadme(errorStr)
                    isCoreFlesReported = gistHandler.gistAddTraceFile()
                    gistHandler.commitAndPush()
                except (OSError, IOError) as e:
                    errorStr = 'Error in add test error log(s) to gist repo :' + str(e) + '\n'
                    errorStr += str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")\n" 
                except ValueError as e:
                    if 'token' in str(e):
                        errorStr = str(e) + '\n'
                        errorStr += str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")\n" 
                except:
                    errorStr = "Unexpected problem in add test error log(s) to gist repo error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")"
                finally:
                    if 'e' in locals():
                        print(errorStr)
                    pass
                result += '\n' + errorStr
            pass
        else:
            for prefix in prefixes:
                _result = []
                if isGitHubComment:
                    _result.append("\\n| " + prefix + " | " + targets[0] + " | " + targets[1] + " | " + targets[2] + " |")
                    _result.append("| ----- | ----- | ----- | ---- |")
                else:
                    _result.append("%-*s %-10s %-10s %-10s" % (20,  prefix,  targets[0],  targets[1],  targets[2]))
                errors = ''
                
                for testname in sorted(logs[prefix],  key=str.lower) :
                    #items = testname.split('.')
                    #line = "%-*s " % (20,  items[1])
                    if len(logs[prefix][testname]) == 0:
                        continue
                    if isGitHubComment:
                        line = "| "+ testname + " "
                    else:
                        line = "%-*s " % (20,  testname)
                    
                    for target in targets:
                        if target in logs[prefix][testname]:
                            if isGitHubComment:
                                line += "| " + logs[prefix][testname][target]['result']+ " "
                                if logs[prefix][testname][target]['result'] == 'Fail':
                                    errors += testname + ' on '+target+' failed with:\\n'+'\\n'.join(logs[prefix][testname][target]['errMsg'])+'\\n'
                            else:
                                line += "%-10s" % (logs[prefix][testname][target]['result'])
                                if logs[prefix][testname][target]['result'] == 'Fail':
                                    errors += testname + ' on '+target+' failed with:\n'+'\n'.join(logs[prefix][testname][target]['errMsg'])+'\n'
                        else:
                            if isGitHubComment:
                                line += "| Excl. "
                            else:
                                line += "%-10s" % ("Excl.")
                    if isGitHubComment:
                        _result.append(line + "|")
                    else:
                        _result.append(line)    
                if len(errors):
                    _result.append(' ')
                    _result.append('```xml')
                    _result.append(errors)
                    _result.append('```')
                _result.append(' ')
                result += ''.join(_result)
            pass
    return (result, isCoreFlesReported)

def ProcessPrBody(bodyText):
    lines = bodyText.split('\n')
    checkBox = re.compile('\s*-\s*\[(.*)\]\s*(.*)$')
    retVal = { 'notification' : False, 'testDraft' : False }
    for line in lines:
        if not line:
            continue
            
        m = checkBox.match(line)
        if m and ( 'x' in m.group(1)):
            if 'queue' in m.group(2):
                retVal['notification'] = True
            elif 'draft' in m.group(2):
                retVal['testDraft'] = True
            
#            print("\t%s" % (str(m.groups())))
#            retVal[m.group(2)] = m.group(1)
            pass
        pass
    return retVal

def GetPullReqCommitId(prid):
    retVal = ''
    if gitHubToken != "":
        try:
            myProc = subprocess.Popen(['curl --request GET -H "Content-Type: application/json" -H "Authorization: token %s" https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls/%s' % (gitHubToken, prid)],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            result = myProc.stdout.read()
            pullInfo = json.loads(result)
            retVal = pullInfo['head']['sha']
        except:
            print("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
            pass
            
    pass
    return retVal
    
def GetOpenPulls(knownPullRequests):
    prs={}
    prSkipped = {}
    openPRs = 0
    newPRs = 0
    buildPr = 0
    updatedPRs = 0
    forcedPr = 0
    testedPRs = 0
    skippedPRs = 0
    try:
        # Delete old pullRequest*.json files.
        files = glob.glob( "pullRequests*.json")
        for file in files:
            os.unlink(file)
            
        # Get pull requests
        # wget -OpullRequests.json https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls
        #
        # This solution tries to get PR info with stanadard GitHub API. If the pullRequests.json file
        # doesn't have 'draft' attribute then use the experimental API (via Accept header) to get extended result
        headers = '--header "Authorization: token ' +  gitHubToken + '"'
        # Using wget (problems on Replacement MFA machines)
        #myProc = subprocess.Popen(["wget -S " + headers + " -OpullRequests.json https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)

        # Using curl
        myProc = subprocess.Popen(["curl " + headers + " -opullRequests.json https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
        
        result = myProc.stdout.read() + myProc.stderr.read()
        pulls_data = open('pullRequests.json').read()
        if '"draft":' not in pulls_data:
            print("Use an experimental GitHub api to determine draft pull requests")
            headers += " '--header=User-Agent: Mozilla/5.0 (Windows NT 6.0) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.97 Safari/537.11'"
            headers += " '--header=Accept:application/vnd.github.shadow-cat-preview'"
            # Using wget (problems on Replacement MFA machines)
            #myProc = subprocess.Popen(["wget -S " + headers + " -OpullRequests.json https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            
            # Using curl
            myProc = subprocess.Popen(["curl " + headers + " -opullRequests.json https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
 
            result = myProc.stdout.read() + myProc.stderr.read()
            
        # get headers
        myProc = subprocess.Popen(["curl --head " + headers + " https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
        result = myProc.stdout.read() + myProc.stderr.read()
            
            # With curl
            #myProc = subprocess.Popen(["curl -S " + headers + " -i -o pullRequests.json https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            #(result,  retCode) = formatResult(myProc)
        morePages = []
        if 'Link:' in result:
            lines = result.split()
            # <https://api.github.com/repositories/2030681/pulls?page=2>;
            nextPageUrlIndex = lines.index('Link:') + 1
            nextPageUrl = lines[nextPageUrlIndex].replace('<', '').replace('>;', '')
            nextPageIndex = int(re.search('(?<=page=)\d+', nextPageUrl).group(0))
            # <https://api.github.com/repositories/2030681/pulls?page=2>;
            lastPageUrlIndex = nextPageUrlIndex + 2;
            lastPageUrl = lines[lastPageUrlIndex].replace('<', '').replace('>;', '')
            lastPageIndex = int(re.search('(?<=page=)\d+', lastPageUrl).group(0))
            for page in range(nextPageIndex,  lastPageIndex+1):
                #myProc = subprocess.Popen(["wget -S " + headers + " -OpullRequests"+str(page)+".json https://api.github.com/repositories/2030681/pulls?page="+str(page)],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                # Using wget (problems on Replacement MFA machines)
                #myProc = subprocess.Popen(["wget -S " + headers + " -OpullRequests"+str(page)+".json https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls?page="+str(page)], shell=True, bufsize=8192, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                # Using curl
                myProc = subprocess.Popen(["curl " + headers + " -opullRequests"+str(page)+".json https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls?page="+str(page)],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                result = myProc.stdout.read() + myProc.stderr.read()

                # With curl
                #myProc = subprocess.Popen(["curl -S " + headers + " -opullRequests"+str(page)+".json https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls?page="+str(page)], shell=True, bufsize=8192, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                
                result = myProc.stdout.read() + myProc.stderr.read()
                pulls_data2 = open('pullRequests' + str(page) + '.json').read()
                pulls_data2 = ',\n'+pulls_data2.lstrip('[').rstrip(']\n')
                morePages.append(pulls_data2)
            pass
            
        pulls_data = open('pullRequests.json').read()
        if len(morePages) > 0:
            pulls_data = pulls_data.rstrip(']\n')
            for page in morePages:
                #pulls_data += pulls_data2
                pulls_data += page
            pulls_data += ']\n'
        pulls = json.loads(pulls_data)
    except ValueError as ve:
        print("Value Error: " + str(ve))
        print("Result: " + str(result))
        # Possible to get open pulls data failed and there is no data (0 length pullRequests.json file)
        # Empty the knownPullRequest list ot avoid the further processing 
        # they are closed and move them out
        del knownPullRequests[:]
        return (prs, buildPr, prSkipped)
    except Exception as ex:
        print("Unable to get pulls "+ str(ex))
        #print("Result: " + str(result))
        # Something bad happened when try to get open pulls data 
        # Empty the knownPullRequest list ot avoid the further processing  
        # they are closed and move them out
        del knownPullRequests[:]
        return (prs, buildPr, prSkipped)
    finally:
        pass

    #print(pulls)
    # It can be determine if a PR mergeable or not in two steps:
    # 1. wget -OpullRequest<PRID>.json https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls/<PRID>
    # 2. cat pullRequest<PRID>.json | grep -i 'mergeable"'
    # The result is '"mergeable": true,' or '"mergeable": false,'
    openPRs = len(pulls)
    print("Number of open PRs: %2d" % ( openPRs ))
    try:
        if (openPRs == 0) or ( (openPRs > 0) and ('number' not in pulls[0])):
            # Possible to get open pulls data failed and there is no PR data (only an error message in pullRequests.json file)
            # Empty the knownPullRequest list ot avoid the further processing 
            # they are closed and move them out
            del knownPullRequests[:]
            return (prs, buildPr, prSkipped)
    except Exception as e:
        print("Something wrong with the pulls[] "+ str(e))
        print("Dump of pulls[]:")
        print(pulls)
        print("End.--------")
        del knownPullRequests[:]
        return (prs, buildPr, prSkipped)
        
    for pr in pulls:
        try:
            prid = pr['number']
        except:
            # Something happened in GitHub,  the reply is not as expected.
            print("Missing pr['number'] from pr(%s)" % (repr(pr)))
            continue
            pass
        
        prs[prid] = {'user':pr['user']['login'], 'code_base':pr['base']['ref'],  'label':pr['head']['ref'].encode('ascii','replace'),
                            'sha':pr['head']['sha'], 'title':pr['title'], 'draft':False }
        
        prs[prid]['checkBoxes'] = ProcessPrBody(pr['body'])
        
        if ('draft' in pr) and (skipDraftPr == False) and not prs[prid]['checkBoxes']['testDraft']:
            prs[prid]['draft'] = pr['draft']
        
        #prs[prid]['cmd'] = 'git fetch -ff upstream pull/'+str(prid)+'/head:'+repr(pr['head']['ref'])+'-smoketest'

        # 2018-05-02 -ff fall back to interactive, forbid it with --no-edit parameter.
        # It can be git/github or master branch problem and not Smoketest, but solved here
        #prs[prid]['cmd'] = 'git pull -ff upstream pull/'+str(prid)+'/head:'+repr(pr['head']['ref'])+'-smoketest'
        prs[prid]['cmd'] = 'git pull -ff --no-edit upstream pull/'+str(prid)+'/head:'+repr(pr['head']['ref'])+'-smoketest'

        # On some version of git there is not "--no-edit" parameter like in OBT-011 system
        prs[prid]['cmd2'] = 'git pull -ff  upstream pull/'+str(prid)+'/head:'+repr(pr['head']['ref'])+'-smoketest'
        
        prs[prid]['addComment'] = {}
        prs[prid]['addComment']['cmd'] = 'curl -H "Content-Type: application/json" '\
                                '-H "Authorization: token ' + gitHubToken +'" '\
                                ' --data '
        prs[prid]['addComment']['url'] = 'https://api.github.com/repos/hpcc-systems/HPCC-Platform/issues/'+str(prid)+'/comments'
        
        prs[prid]['testfiles'] = []
        prs[prid]['regSuiteTests'] = ''
        prs[prid]['sourcefiles'] = []
        prs[prid]['newSubmodule'] = False
        prs[prid]['isDocsChanged'] = False
        prs[prid]['runUnittests'] = False
        prs[prid]['runWutoolTests'] = False
        prs[prid]['buildEclWatch'] = buildEclWatch
        prs[prid]['inQueue'] = False
        prs[prid]['reason'] = ''
        prs[prid]['buildOnly'] = False
        prs[prid]['sessionTime'] = averageSessionTime   # default, average full test competion time
        prs[prid]['enableStackTrace'] = True
        prs[prid]['excludeFromTest'] = False
        
        testDir = 'smoketest-'+str(prid)
        # mkdir smoketest-<PRID>
        if not os.path.exists(testDir):
            testDir = 'PR-'+str(prid)
            if not os.path.exists(testDir):
                if not os.path.exists('OldPrs/'+testDir):
                    os.mkdir(testDir)
                else:
                    # PR reopend or GitHub plays funny
                    # mv archived PR back from OldPrs directory
                    print ("Move closed "+ testDir + " directory from OldPrs/ back to smoketest directory.")
                    myProc = subprocess.Popen(["mv -f " + 'OldPrs/'+ testDir +" ."],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                    (myStdout,  myStderr) = myProc.communicate()
                    result = "returncode:" + str(myProc.returncode) + ", stdout:'" + myStdout + "', stderr:'" + myStderr.replace('\n','') + "'."
                    print("Result: "+result)
                    pass

        try:
            myPrint("testDir: " + testDir)
            # This pull request still open, keep it
            if testDir in knownPullRequests:
                myPrint("Remove: " + testDir + " from knownPullRequests[]")
                knownPullRequests.remove(testDir)
                
        except:
            print("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
            pass
            
        prs[prid]['testDir'] = testDir
        
        shaFileName = os.path.join(testDir, 'sha.dat')
        if not os.path.exists(shaFileName):
            # Create sha.dat file
            outFile = open(shaFileName,  "wb")
            outFile.write(pr['head']['sha'])
            outFile.close()
            
        # check sha.dat file
        shaFile = open(shaFileName,  "rb")
        sha = shaFile.readline()
        shaFile.close()
        newSha=pr['head']['sha']
        
        baseBranchFileName = os.path.join(testDir, 'baseBranch.dat')
        newBaseBranch = pr['base']['ref']
        if not os.path.exists(baseBranchFileName):
            # Create sha.dat file
            baseBranchFile = open(baseBranchFileName,  "wb")
            baseBranchFile.write(newBaseBranch)
            baseBranchFile.close()
            baseBranch = pr['base']['ref']
        else:    
            # check baseBranch.dat file
            baseBranchFile = open(baseBranchFileName,  "rb")
            baseBranch = baseBranchFile.readline()
            baseBranchFile.close()
        
        
        #check build.summary file
        buildSummaryFileName = os.path.join(testDir, 'build.summary')
#        buildSuccess= False
        isBuilt = False
        if os.path.exists(buildSummaryFileName):
            isBuilt=True
            # The result of this code block never used, remove 
#            buildSummaryFile = open(buildSummaryFileName, 'r')
#            buildSummary = buildSummaryFile.readlines()
#            buildSummaryFile.close()
#            for line in buildSummary:
#                if "Build success" in line:
#                    buildSuccess = True
#                    break
                    
        if isBuilt and (testPrNo == str(prid)):
            # Force to rebuild and retest
            isBuilt = False
            
        isNotDraft = prs[prid]['draft'] == False
        isChangedOrNew = (sha != newSha) or (baseBranch != newBaseBranch) or (not isBuilt)
        
        if isNotDraft and isChangedOrNew:
            # generates changed file list:
            # wget -O<PRID>.diff https://github.com/hpcc-systems/HPCC-Platform/pull/<PRID>.diff
            #myProc = subprocess.Popen(["wget --timeout=60 -O"+testDir+"/"+str(prid)+".diff https://github.com/hpcc-systems/HPCC-Platform/pull/"+str(prid)+".diff"],  shell=True,  bufsize=65536,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            # With curl
            myProc = subprocess.Popen(["curl -L --connect-timeout 60 -o"+testDir+"/"+str(prid)+".diff https://github.com/hpcc-systems/HPCC-Platform/pull/"+str(prid)+".diff"],  shell=True,  bufsize=65536,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            # The myProc.stdout.read() hanged if there was a large (> 40MB) diff file to get.
            (result,  err) = myProc.communicate()
            result = result.rstrip('\n').split('\n')
            err = err.rstrip('\n').split('\n')
            
            # cat <PRID>.diff | grep '[d]iff' | awk '{ print $3 }' | sed 's/a\///'
            # gives the changes source files with path
            #prs[pr['number']]['files'] = output of command
            
            myProc = subprocess.Popen(["cat "+testDir+"/"+str(prid)+".diff | grep '^[d]iff ' | awk '{ print $3 }' | sed 's/a\///'"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            result = myProc.stdout.read().rstrip('\n').split('\n')
            prs[prid]['files'] = result
            
            changedFilesFileName = os.path.join(testDir, 'changedFiles.txt')
            oldChangedFilesFileName = os.path.join(testDir, 'changedFiles.old')
            if os.path.exists(oldChangedFilesFileName):
                os.unlink(oldChangedFilesFileName)
                
            if os.path.exists(changedFilesFileName):
                os.rename(changedFilesFileName,  oldChangedFilesFileName)
            
            # Check directory exclusions
            #prs[prid]['excludeFromTest'] = any([True for x in prs[prid]['files'] if ('^helm/' in x ) or ('^dockerfiles/' in x) or ('.github/' in x)] )
            excludePaths = ['helm/', 'dockerfiles/', '.github/', 'testing/helm/', 'MyDockerfile/']
            #prs[prid]['excludeFromTest'] = any([True for x in prs[prid]['files'] if any( [True for y in excludePaths if x.startswith(y) ])] )
            t = [True for x in prs[prid]['files'] if any( [True for y in excludePaths if x.startswith(y) ])]
            if len(t) == len(prs[prid]['files']):
                # if the number of files in exludePaths is equal to the number of changed files then skip it.
                prs[prid]['excludeFromTest'] = True
        
        isNotExcluded = prs[prid]['excludeFromTest'] == False
        
        if isNotDraft and isChangedOrNew and isNotExcluded:
            # New commit occurred or it didn't build yet
            prs[prid]['reason']="Did not build yet"
            if sha != newSha:
                updatedPRs +=1
                # rename old sha file from sha.dat to sha.old
                oldShaFileName = os.path.join(testDir, 'sha.old')
                if os.path.exists(oldShaFileName):
                    os.unlink(oldShaFileName)
                os.rename(shaFileName,  oldShaFileName)
                # Update sha.dat file
                outFile = open(shaFileName,  "wb")
                outFile.write(pr['head']['sha'])
                outFile.close()
                prs[prid]['reason']="New commit"
            elif baseBranch != newBaseBranch:
                updatedPRs +=1
                # rename old baseBranch file from baseBranch.dat to baseBranch.old
                oldBaseBranchFileName = os.path.join(testDir, 'baseBranch.old')
                if os.path.exists(oldBaseBranchFileName):
                    os.unlink(oldBaseBranchFileName)
                os.rename(baseBranchFileName,  oldBaseBranchFileName)
                # Update baseBranch.dat file
                outFile = open(baseBranchFileName,  "wb")
                outFile.write(newBaseBranch)
                outFile.close()
                prs[prid]['reason']="Base branch changed"
            elif testPrNo == str(prid):
                forcedPr += 1
                prs[prid]['reason']="Forced to re-test"
            else:
                newPRs += 1
            #print("Build PR-"+str(prid)+", label: "+prs[prid]['label']+' sheduled to testing ('+prs[prid]['reason']+')')
    
#            # generates changed file list:
#            # wget -O<PRID>.diff https://github.com/hpcc-systems/HPCC-Platform/pull/<PRID>.diff
#            #myProc = subprocess.Popen(["wget --timeout=60 -O"+testDir+"/"+str(prid)+".diff https://github.com/hpcc-systems/HPCC-Platform/pull/"+str(prid)+".diff"],  shell=True,  bufsize=65536,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#            # With curl
#            myProc = subprocess.Popen(["curl -L --connect-timeout 60 -o"+testDir+"/"+str(prid)+".diff https://github.com/hpcc-systems/HPCC-Platform/pull/"+str(prid)+".diff"],  shell=True,  bufsize=65536,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#            # The myProc.stdout.read() hanged if there was a large (> 40MB) diff file to get.
#            (result,  err) = myProc.communicate()
#            result = result.rstrip('\n').split('\n')
#            err = err.rstrip('\n').split('\n')
#            
#            # cat <PRID>.diff | grep '[d]iff' | awk '{ print $3 }' | sed 's/a\///'
#            # gives the changes source files with path
#            #prs[pr['number']]['files'] = output of command
#            
#            myProc = subprocess.Popen(["cat "+testDir+"/"+str(prid)+".diff | grep '[d]iff ' | awk '{ print $3 }' | sed 's/a\///'"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#            result = myProc.stdout.read().rstrip('\n').split('\n')
#            prs[prid]['files'] = result
#            
#            changedFilesFileName = os.path.join(testDir, 'changedFiles.txt')
#            oldChangedFilesFileName = os.path.join(testDir, 'changedFiles.old')
#            if os.path.exists(oldChangedFilesFileName):
#                os.unlink(oldChangedFilesFileName)
#                
#            if os.path.exists(changedFilesFileName):
#                os.rename(changedFilesFileName,  oldChangedFilesFileName)
                
            changedFilesFile = open(changedFilesFileName,  "wb")
            for changedFile in  prs[prid]['files']:
                if changedFile.startswith('testing/regress/ecl/'):
                    # If a changed file is in the setup directory it shouldn't execute separately
                    if ('setup/' not in changedFile) and (changedFile.endswith('.ecl')):
                        prs[prid]['testfiles'].append(changedFile)
                    if changedFile.endswith('.xml'):
                        prs[prid]['testfiles'].append(changedFile.replace('.xml', '.ecl'))
                    if changedFile.endswith('.eclccwarn'):
                        prs[prid]['testfiles'].append(changedFile.replace('.eclccwarn', '.ecl'))
                    if changedFile.startswith('testing/regress/ecl/library'):
                        prs[prid]['testfiles'].append('testing/regress/ecl/aaalibrary*')
                elif changedFile.startswith('testing/regress/'):
                    if changedFile.endswith('.py') or changedFile.endswith('ecl-test'):
                        print("RTE changed: %s" % (changedFile))
                        # Something changed in the engine should test it
                        prs[prid]['testfiles'].append('testing/regress/ecl/teststdlibrary.ecl')
                elif changedFile.startswith('ecllibrary/teststd/') or changedFile.startswith('ecllibrary/std/') :
                    if changedFile.endswith('.ecl'):
                        prs[prid]['testfiles'].append('testing/regress/ecl/teststdlibrary.ecl')
                elif (changedFile.startswith('docs/') or changedFile.endswith('.rst')):
                    prs[prid]['isDocsChanged'] = True
                elif changedFile.endswith('.c') or changedFile.endswith('.cpp'):    
                    prs[prid]['sourcefiles'].append(changedFile)
                elif '.gitmodules' == changedFile:
                    prs[prid]['newSubmodule'] = True
                elif changedFile.startswith('esp/src/'):
                    # Buiild ECLWatch in and only if something changed in its source
                    prs[prid]['buildEclWatch'] = True
#                elif changedFile.startswith('helm') or changedFile.startswith('Dockefiles'):
#                    prs[prid]['excludeFromTest'] = True
                    
                changedFilesFile.write( changedFile+'\n' )
            changedFilesFile.close()
            
            # If only the documentation or the ECLWatch changed, we skip testig
            if (prs[prid]['buildEclWatch'] or prs[prid]['isDocsChanged'] ) and ( len(prs[prid]['testfiles']) == 0 ) and (len(prs[prid]['sourcefiles']) == 0):
                    prs[prid]['buildOnly'] = True
                    # TO-DO we need some flexible solution
                    if prs[prid]['buildEclWatch']:
                        prs[prid]['sessionTime'] = averageSessionTime / 5 # guestimation of completion time
                    elif prs[prid]['isDocsChanged']:
                        prs[prid]['sessionTime'] = averageSessionTime / 4 # guestimation of completion time
            else:    
                if runFullRegression:
                    prs[prid]['testfiles'] = ['*.ecl']
                    if prs[prid]['buildEclWatch']:
                        prs[prid]['sessionTime'] += averageSessionTime / 5 # guestimation of completion time
                    if prs[prid]['isDocsChanged']:
                        prs[prid]['sessionTime'] += averageSessionTime / 4 # guestimation of completion time
                    
                # Check base version to execute Unit Tests
                unittestMinVersion={'major':6, 'minor':0,  'release':2}
                baseVersion = prs[prid]['code_base'].split('-')
                if len(baseVersion) >= 2:
                    baseVersionItems = baseVersion[1].split('.')
                    if len(baseVersionItems) >= 3:
                        if int(baseVersionItems[0]) == unittestMinVersion['major']:
                            if 'x' == baseVersionItems[2] or 'beta' in baseVersionItems[2]:
                                prs[prid]['runUnittests'] = True
                            elif (int(baseVersionItems[1]) > unittestMinVersion['minor']):
                                prs[prid]['runUnittests'] = True
                            elif ((int(baseVersionItems[1]) == unittestMinVersion['minor']) 
                                and (int(baseVersionItems[2]) >= unittestMinVersion['release'])):
                                prs[prid]['runUnittests'] = True
                        elif int(baseVersionItems[0]) > unittestMinVersion['major']:
                            prs[prid]['runUnittests'] = True
                        pass
                    pass
                elif (len(baseVersion) == 1) and ('master' == baseVersion[0]):
                    prs[prid]['runUnittests'] = True
                
                # Check base version to enable stack trace
                stackTraceMinVersion={'major':7, 'minor':2,  'release':22}
                baseVersion = prs[prid]['code_base'].split('-')
                if len(baseVersion) >= 2:
                    baseVersionItems = baseVersion[1].split('.')
                    if len(baseVersionItems) >= 3:
                        if int(baseVersionItems[0]) == stackTraceMinVersion['major']:
                            if (int(baseVersionItems[1]) < stackTraceMinVersion['minor']):
                                prs[prid]['enableStackTrace'] = False
                            elif (int(baseVersionItems[1]) == stackTraceMinVersion['minor']):
                               if ('x' not in baseVersionItems[2]) and (int(baseVersionItems[2]) < stackTraceMinVersion['release']):
                                prs[prid]['enableStackTrace'] = False
                        elif int(baseVersionItems[0]) < stackTraceMinVersion['major']:
                            prs[prid]['enableStackTrace'] = False
                        pass
                    pass
                
                # Check base version to execute Wutool -selftest
                wutoolsMinVersion={'major':6, 'minor':2,  'release':6}
                baseVersion = prs[prid]['code_base'].split('-')
                if len(baseVersion) >= 2:
                    baseVersionItems == baseVersion[1].split('.')
                    if len(baseVersionItems) >= 3:
                        if int(baseVersionItems[0]) == wutoolsMinVersion['major']:
                            if (int(baseVersionItems[1]) == wutoolsMinVersion['minor']) and ('x' == baseVersionItems[2]):
                                prs[prid]['runWutoolTests'] = False
                            elif 'x' == baseVersionItems[2] or 'beta' in baseVersionItems[2]:
                                prs[prid]['runWutoolTests'] = True
                            elif (int(baseVersionItems[1]) > wutoolsMinVersion['minor']):
                                prs[prid]['runWutoolTests'] = True
                            elif ((int(baseVersionItems[1]) == wutoolsMinVersion['minor']) 
                                and (int(baseVersionItems[2]) >= wutoolsMinVersion['release'])):
                                prs[prid]['runWutoolTests'] = True
                            pass
                        elif int(baseVersionItems[0]) > unittestMinVersion['major']:
                            prs[prid]['runWutoolTests'] = True
                        pass
                    pass
                elif (len(baseVersion) == 1) and ('master' == baseVersion[0]):
                    prs[prid]['runWutoolTests'] = True
                
                if prid == 9166:
                    prs[prid]['testfiles'].append('testing/regress/ecl/teststdlibrary.ecl')
                    
                if len(prs[prid]['testfiles']) > 0:
                    prs[prid]['regSuiteTests'] ='"' + WildGen(prs[prid]['testfiles']) + '"'
                
            if isBuilt:
                os.unlink(buildSummaryFileName)
                
            #if prs[prid]['isDocsChanged']: # and not os.path.exists(buildSummaryFileName):
                # buildSummaryFile = open(buildSummaryFileName,  "wb")
                # buildSummaryFile.write( "Only documentation changed! Don't build." )
                # buildSummaryFile.close()
                # print("In PR-"+str(prid)+", label: "+prs[prid]['label']+" only documentation changed! Don't sheduled to testing ")

            if prs[prid]['excludeFromTest']:
                print("Build PR-"+str(prid)+", label: "+prs[prid]['label']+' is excluded from test (helm or Dockerfile related), skip it!')
                skippedPRs += 1
            else:
                prs[prid]['inQueue'] = True
                buildPr += 1
                #print("Build PR-"+str(prid)+", label: "+prs[prid]['label']+" scheduled to testing (reason:'"+prs[prid]['reason']+"', is DOCS changed:"+str(prs[prid]['isDocsChanged'])+")")
                print("Build PR-%s, label: %s scheduled to testing (reason:'%s', is DOCS changed: %s, is ECLWatch build: %s)" % (str(prid), prs[prid]['label'], prs[prid]['reason'], str(prs[prid]['isDocsChanged']), str(prs[prid]['buildEclWatch']) ) )
            pass
            
            
        elif prs[prid]['excludeFromTest']:
            print("Build PR-"+str(prid)+", label: "+prs[prid]['label']+' is excluded from test (helm or Dockerfile related), skip it!')
            skippedPRs += 1
        else:
            if pr['draft'] == False:
                print("Build PR-"+str(prid)+", label: "+prs[prid]['label']+' already tested!')
                testedPRs += 1
            else:
                print("Build PR-"+str(prid)+", label: "+prs[prid]['label']+' is in draft state, skip it!')
                skippedPRs += 1
    
    # Until this point all open PR is removed from knownPullRequests
    closedActive = 0
    print("[%s] - Check if there is any closed but still running task..." % (threading.current_thread().name))
    for key in sorted(threads):
        testDir = 'PR-' + key
        if (testDir in knownPullRequests):
            if threads[key]['thread'].is_alive():
                elaps = time.time()-threads[key]['startTimestamp']
                print("--- Keep PR-%s (%s) until it is finished. (started at: %s, elaps: %d sec, %d min))"  % (key, threads[key]['commitId'], threads[key]['startTime'], elaps,  elaps / 60 ) )
                knownPullRequests.remove(testDir)
                closedActive += 1
    if closedActive == 0:
        print("[%s] - None\n" % (threading.current_thread().name))
    else:
        print("[%s] - End of list\n" % (threading.current_thread().name))
        
    print("")
    
    print("Number of closed, but still active PRs : %2d" % (closedActive))
    print("Number of open PRs                     : %2d" % (openPRs))
    print("Number of tested PRs                   : %2d" % (testedPRs))
    print("Number of skipped PRs                  : %2d" % (skippedPRs))
    print("Number of new PRs                      : %2d" % (newPRs))
    print("Number of updated PRs                  : %2d" % (updatedPRs))
    print("Number of forced PRs                   : %2d" % (forcedPr))
    print("-------------------------------------------")
    if forcedPr > 0:
        print("Number of PRs to build                 : %2d (forced)" % (forcedPr))
    else:
        print("Number of PRs to build                 : %2d" % (buildPr))
    
    prQueue = {}
    for pr in prs:
        if prs[pr]['inQueue']:
            prQueue[pr] = prs[pr]
            
        if prs[pr]['excludeFromTest']:
            prSkipped[pr] = prs[pr]
            
    #return (prs, buildPr)
    return (prQueue, buildPr, prSkipped)

def CleanUpClosedPulls(knownPullRequests, smoketestHome):
    # Clear old smoketets/pull request branches?
    # The old (closed) pull request branch is which left in knownPullRequests array after the 
    # open pull request list processed
    os.chdir(smoketestHome)
    newlyClosedPrs = 0;
    if 0 < len(knownPullRequests):
        print("")
        # we have some closed PR
        for pullReqDir in knownPullRequests:
            # Is this pull request under the testing (but, it is closed meanwhile, therefore not in open pull requests)
            prIdStr=pullReqDir.replace('PR-', '')
            if prIdStr in threads:
                # Yes, skip it
                print("%s" % (pullReqDir) )
                if threads[prIdStr]['thread'].is_alive():
                    print("\tIt is still in 'threads' and alive skip it.")
                    continue
                else:
                    print("\tIt is finished and closed, remove from 'threads'")
                    del threads[prIdStr]
                
            newlyClosedPrs +=1
            # to save disk space delete its HPCC-Platfrom and build directories.
            if os.path.exists(pullReqDir+"/HPCC-Platform") or os.path.exists(pullReqDir+"/build"):
                print ("Delete HPCC-Platform and build directories of the closed "+pullReqDir)
                myProc = subprocess.Popen(["sudo -S rm -rf "+pullReqDir+"/HPCC-Platform "+pullReqDir+"/build"],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                (myStdout,  myStderr) = myProc.communicate(input = myPassw)
                result = "returncode:" + str(myProc.returncode) + ", stdout:'" + myStdout + "', stderr:'" + myStderr + "'."
                print("Result: "+result)
            # Remove gists
            os.chdir(pullReqDir)
            try:
                gistHandler = GistLogHandler(gitHubToken)
                gistHandler.removeGists(True)
                os.chdir(smoketestHome)
            except ValueError as e:
                if 'token' in str(e):
                    errorStr = str(e) + '\n'
                    errorStr += str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")\n" 
                    print(errorStr)
                    
            print ("Move closed "+ pullReqDir + " directory to OldPrs/ .")
            myProc = subprocess.Popen(["mv -f " + pullReqDir +" OldPrs/"],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            (myStdout,  myStderr) = myProc.communicate()
            result = "returncode:" + str(myProc.returncode) + ", stdout:'" + myStdout + "', stderr:'" + myStderr.replace('\n','') + "'."
            print("\tResult: "+result)
            
            if myProc.returncode != 0 and 'cannot move' in myStderr:
                # Handle the rare situation when PR directory already exists in OldPrs
                # Copy all files from <pullReqDir> dir to OldPrs/<pullReqDir>
                print ("\tCopy files from "+ pullReqDir + " closed directory to OldPrs/ .")
                cmd = "cp -rf " + pullReqDir +"/* OldPrs/" + pullReqDir + "/."
                print ("\tcmd:" + cmd)
                myProc = subprocess.Popen([ cmd ],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                (myStdout,  myStderr) = myProc.communicate()
                result = "returncode:" + str(myProc.returncode) + ", stdout:'" + myStdout + "', stderr:'" + myStderr + "'."
                print("\tResult: "+result)
                if myProc.returncode == 0:
                    # Remove <pullReqDir>
                    print ("\tRemove "+ pullReqDir + " directory.")
                    cmd = "rm -rf " + pullReqDir
                    print ("\tcmd:" + cmd)
                    myProc = subprocess.Popen([ cmd],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                    (myStdout,  myStderr) = myProc.communicate()
                    result = "returncode:" + str(myProc.returncode) + ", stdout:'" + myStdout + "', stderr:'" + myStderr + "'."
                    print("\tResult: "+result)
                               
    if newlyClosedPrs == 0:
        print("\nNo PR closed from last run.\n")
    else:
        print("\n%s PR(s) are closed and moved to OldPrs directory.\n" % ( str(newlyClosedPrs) ))

def formatResult(proc, resultFile = None, echo = True):
    (stdout, stderr) = proc.communicate()
    retcode = proc.wait()
 
    if len(stdout) == 0:
        stdout = 'None'
    
    if len(stderr) == 0:
        stderr = 'None'
        
    result = "returncode: " + str(retcode) + "\n\t\tstdout: " + stdout + "\n\t\tstderr: " + stderr
    
    if not 'remote upstream already exists' in result:
        if len(result) > 0 and echo:
            print("\t\t"+result)
        else:
            print("\t\tOK")
    
    if resultFile != None:
        try:
            resultFile.write("\tresult:"+result+"\n")
        except:
            pass
            
    return (result, retcode)
    
def CatchUpMaster():
    print("Catch up master")
    # git clone https://github.com/hpcc-systems/HPCC-Platform.git
    # git remote add upstream git@github.com:hpcc-systems/HPCC-Platform.git
    
    try:
        if not os.path.exists('HPCC-Platform'):
            # Clone it
            print("\tHPCC-Platform doesn't exist, clone it.")
            if enableShallowClone:
                # Experimental, but can cause problem with older candidates/PRs
                myProc = subprocess.Popen(["git clone --depth 100 https://github.com/HPCC-Systems/HPCC-Platform.git"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            else:
                myProc = subprocess.Popen(["git clone https://github.com/HPCC-Systems/HPCC-Platform.git"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            formatResult(myProc)
            
            os.chdir('HPCC-Platform')
            
            # Set up upstream!!!!
            print("\tgit remote add upstream git@github.com:hpcc-systems/HPCC-Platform.git")
            myProc = subprocess.Popen(["git remote add upstream https://" + gitHubToken + "@github.com/hpcc-systems/HPCC-Platform.git"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            formatResult(myProc)
    
            # Set up origin
            print("\tgit remote remove origin")
            myProc = subprocess.Popen(["git remote remove origin"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            formatResult(myProc)
            
            print("\tgit remote add origin git@github.com:HPCCSmoketest/HPCC-Platform")
            myProc = subprocess.Popen(["git remote add origin https://" + gitHubToken + "@github.com/HPCCSmoketest/HPCC-Platform"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            formatResult(myProc)
            
            # Somehow the clone doesn't crate all branches (candidates) and it can cause problem for PRs on older base branch
            print("\tgit fetch upstream")
            myProc = subprocess.Popen(["git fetch upstream"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            formatResult(myProc)
            
            #Add these
            # git config --global user.name "HPCCSmoketest"
            # git config --global user.email "hpccsmoketest@gmail.com"
        else:   
            # Catch up
            print("\tUpdate HPCC-Platform.")
            os.chdir('HPCC-Platform')
            
            # Set up upstream!!!!
            myProc = subprocess.Popen(["git remote add upstream https://" + gitHubToken + "@github.com/hpcc-systems/HPCC-Platform.git"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            formatResult(myProc)
                    
            myProc = subprocess.Popen(["git checkout master"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            formatResult(myProc)
    
            print("\tgit fetch upstream")
            myProc = subprocess.Popen(["git fetch upstream"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            formatResult(myProc)
    
            print("\tgit merge --ff-only upstream/master")
            myProc = subprocess.Popen(["git merge --ff-only upstream/master"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            formatResult(myProc)
            
            # Smoketest has no right to push
            # print("\tgit push origin master")
            # myProc = subprocess.Popen(["git push origin master"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            # result = formatResult(myProc)
            
        # Update submodule
        # git submodule update --init --recursive
        
        print("\tgit submodule update --init --recursive")
        myProc = subprocess.Popen(["git submodule update --init --recursive"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
        formatResult(myProc)        
        
        # Record master branch info
        print("\tgit log -1 ")
        myProc = subprocess.Popen(["git log -1 "],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
        formatResult(myProc)
        # branchDate=$( git log -1 | grep '^Date' ) 
        # branchCrc=$( git log -1 | grep '^commit' )
        
#        myProc = subprocess.Popen(["ecl --version"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#        result = myProc.stdout.read() + myProc.stderr.read()
#        #results = result.split('\n')
#        print("\t"+result)
            
    except OSError as e:
        print("OS error:" + str(e) + " - " + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
    #    err = Error("6002")
    #    logging.error("%s. checkHpccStatus error:%s!" % (1,  err))
    #    raise Error(err)
        pass
    
    except ValueError as e:
        print("Value error:" + str(e) + " - " + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
    #    err = Error("6003")
    #    logging.error("%s. checkHpccStatus error:%s!" % (1,  err))
    #    raise Error(err)
        pass
    
    except:
        print("Internal error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
        pass
    
    finally:
        print("Catch up maste done.")
        pass
            
    os.chdir("../")
    
class TableGenerator():
    #tableItems=[]
    def __init__(self):
        self.clear()
        pass
        
    def clear(self):
            self.tableItems = {'key':[],  'val':[]}
            
    def completteRow(self):
        if len(self.tableItems['key']) == 0:
            # Nothing to check
            return
        # if any item in the last row is missing put an 'N/A' txt to ballance it out
        # It should call before to add a new row
        index = len(self.tableItems['key'])-1
        # Get the length of the longest sub array/list
        maxLen = len(max(self.tableItems['val'], key=len))
        for index in range(len(self.tableItems['val'])):
            colLen = len(self.tableItems['val'][index])
            if  (colLen != maxLen):
                if colLen == maxLen -1:
                    self.tableItems['val'][index].append('N/A')
                else:
                    print("More then one unballanced row detected! Use completteRow() after every row created")
        pass
        
    def addItem(self,  itemString,  separator=':'):
        parts = itemString.split(separator)
        if len(parts) < 2:
            myPrint("line %5s: Bad formatted string: '%s'." %(str(inspect.stack()[0][2]), itemString))
        else:
            if parts[0] in self.tableItems['key']:
                # Add a new line
                index = self.tableItems['key'].index(parts[0])
                self.tableItems['val'][index].append(parts[1])
            else:
                self.tableItems['key'].append(parts[0])
                self.tableItems['val'].append([parts[1]])
            pass
                
    def getTable(self):
        if len(self.tableItems['key']) == 0:
            return "Empty table"
            
        tableString="\n| "
        separator = "|"
#        values ="|"
        #generate header
        for index in range(0,  len(self.tableItems['key'])):
            tableString += self.tableItems['key'][index] + " | "
            separator += "---|"
        tableString += "\n"+separator+"\n"
        
        for item in range(len( self.tableItems['val'][index])):
            tableString += '|'
            for index in range(0,  len(self.tableItems['val'])):
                try:
                    tableString += self.tableItems['val'][index][item] + " |"
                except:
                    tableString += " N/A |"
            tableString += '\n'
        
        tableString += "\n"
        return tableString

def collectECLWatchBuildErrors():
    eclWatchBuildError = ''
    eclWatchBuildFileName = 'build/esp/src/build/build-report.txt'
    errorSet = set()
    if os.path.exists(eclWatchBuildFileName):
        eclWatchBuildFile = open(eclWatchBuildFileName,  "r")
        eclWatchBuildFileResult = eclWatchBuildFile.readlines()
        eclWatchBuildFile.close()
        lineNo = 0
        for line in eclWatchBuildFileResult:
            if ('error(s),' in line) and not (line.startswith('0')) :
                # Search the start of this erro, a line beginning with a  '/' (path)
                startIndex = lineNo - 1
                while not eclWatchBuildFileResult[startIndex].startswith('/'):
                    startIndex -= 1
                pass
                print( "startIndex:%5d, lineNo:%5d" % (startIndex,  lineNo))
                errorMsg = '\n'.join(eclWatchBuildFileResult[startIndex:lineNo])
                errorMsg = errorMsg.replace('\n\n', '\n').replace('"','\'').strip('\n')
                if errorMsg not in errorSet:
                    errorSet.add(errorMsg)
                    eclWatchBuildError += errorMsg
                    
            lineNo += 1
        
    else:
        eclWatchBuildError += '\n' + eclWatchBuildFileName + ' not found.'
    pass
    return eclWatchBuildError
        
def processResult(result,  msg,  resultFile,  buildFailed=False,  testFailed=False,  testfiles=None,  maxMsgLen=4096, runUnittests=False, runWutoolTests=False,  prid=0, buildEclWatch=False):
    results = result.split('\n')
    startFailed=False
    eclWatchBuild = False
    eclWatchBuildError = ''
    eclWatchTable = TableGenerator()
    eclWatchBuildOk = True
    table = TableGenerator()
    if buildFailed:
        allPassed = False
    else:
        allPassed = True
    npmInstall = False
    npmInstallResultWarn = ''
    npmInstallResultErr = ''
    npmTest=False
    npmTestResultWarn = ''
    npmTestResultErr = ''
    npmTestResult = ''
    timeStats = False
    timeStatsString = ''
    timeStatsTable = TableGenerator()
    wutoolTestErrorLog = ''
    unittestErrorLog = ''
    buildErrorLogAddedToGists = False
    buildErrorStr = ''
    inSuiteErrorLog = False
    suiteErrors = ''
    lineIndex = 0
    coreGenerated = False
    coreMsg = ''
    isCoreFlesReported = False
    
    # TO-DO Check and report core files
    
    for result in results:
        lineIndex += 1
        if resultFile == '':
            print("\t"+result)
        else:
            resultFile.write("\t"+result+"\n")
        #result = result.replace('\n', '\\n')+"\\n"
        if type(result) != type(u' '):
            result = repr(result).replace('\'', '') #.replace('\\\\','\\')+"\n"

        result = result.replace('\n','')
        if len(result) == 0:
            continue
        else:
            result += '\n'
            
        if 'ECL Watch' in result:
            print("\t"+result)
            msg += result.replace('-- ', '')
            eclWatchBuild=True
            table.clear()
            continue
        elif result.startswith('Cores:'):
            print("\t"+result)
            # Cores: 8
            testInfo['cores'] = result.split(':')[1].split()[0]
            continue
        elif result.startswith('CPU speed:'):
            print("\t"+result)
            # CPU speed: 1995 MHz
            testInfo['cpuSpeed'] = result.split(':')[1].split()[0]
            continue
        elif result.startswith('CPU Bogo Mips:'):
            print("\t"+result)
            # CPU Bogo Mips: 3990.43
            testInfo['cpuBogoMips'] = result.split(':')[1].split()[0]
            continue
        elif result.startswith('Parallel queries:'):
            print("\t"+result)
            # Parallel queries: 5
            testInfo['parallelQueries'] = result.split(':')[1].split()[0]
            continue
        elif result.startswith('Build threads:'):
            print("\t"+result)
            # Build threads: 12
            # or it can be without value
            # Build threads:
            items = result.split(':')[1].split()
            if len(items) > 0:
                testInfo['buildThreads'] = items[0]
            else:
                testInfo['buildThreads'] = 'unlimited'
            continue
        elif result.startswith('Total memory:'):
            print("\t"+result)
            # Total memory: 7 GB
            testInfo['totalMemory'] = result.split(':')[1].split()[0]
            continue
        elif result.startswith('Available memory:'):
            print("\t"+result)
            # Available memory: 6 GB
            testInfo['availableMemory'] = result.split(':')[1].split()[0]
            continue
        elif result.startswith('Memory core ratio:'):
            print("\t"+result)
            # Memory core ratio: 0.997 GB/core
            testInfo['memoryCoreRatio'] = result.split(':')[1].split()[0]
            continue
        elif result.startswith('Build: su'):
            print("\t"+result)
            msg += result
            continue
        elif result.startswith('Build: fa'):
            print("\t"+result)
            msg += result
            allPassed = False
        elif result.startswith('Error(s):'):
            buildFailed =  True
            print("\n\t"+result)
            msg += 'Number of '+result
            allPassed = False
            continue;
        elif 'undefined reference' in result:
            buildFailed =  True
            print("\n\t"+result)
            tempRes = result
            msg += tempRes.replace('"','').replace('u\'',  '').replace('\'','')
            allPassed = False
            continue;
        elif 'No such file or directory' in result:
            buildFailed =  True
            print("\n\t"+result)
            tempRes = result
            msg += tempRes.replace('"','').replace('u\'',  '').replace('\'','')
            allPassed = False
            continue;
        elif (buildFailed or not eclWatchBuildOk) and not (result.startswith('[sudo]') or result.startswith('sudo')):
            print("\t\t"+result)
            tempRes = result
            msg += tempRes.replace('"','').replace('u\'',  '').replace('\'','')
            
            if not buildErrorLogAddedToGists and not testmode:
                buildErrorLogAddedToGists = True
                # Add build result to gist repo
                try:
                    gistHandler = GistLogHandler(gitHubToken)
                    gistHandler.createGist(prid)
                    gistHandler.cloneGist()
                    gistHandler.updateReadme('OS: ' + sysId + '\n')
                    buildErrorStr = '[Build error:](' + gistHandler.getGistUrl() + ')\n'
                    try:
                        resultFileName = resultFile.name
                    except:
                        resultFileName = "NoFile"
                    (linkTag,  id) = gistHandler.gistAddBuildError(resultFileName, results)
                    buildErrorStr += 'Build log ' + linkTag + '\n'
                    gistHandler.updateReadme(buildErrorStr)
                    gistHandler.commitAndPush()
                
                except (OSError, IOError) as e:
                    errorStr = 'Error in add build result to gist repo :' + str(e) + '\n'
                    errorStr += str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")\n" 
                
                except ValueError as e:
                    if 'token' in str(e):
                        errorStr = str(e) + '\n'
                        errorStr += str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")\n" 
                
                except:
                    errorStr = "Unexpected problem in add test error log(s) to gist repo error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")"
                finally:
                    if 'errorStr' in locals():
                        print(errorStr)
                        msg +=  '\n' + errorStr + '\n'
                    pass
                #msg +=  '\n' + buildErrorStr + '\n'
                #buildFailed=False
                eclWatchBuildOk=True
            continue   
        elif result.startswith('Milestone:Build'):
#            eclWatchBuild = False
            pass
            
        elif result.startswith('Milestone:Install'):
            if eclWatchBuild:
                eclWatchBuild = False
                eclTableText = eclWatchTable.getTable()
                if not eclTableText.startswith('Empty table'):
                    print(eclTableText)
                    msg += eclTableText + '\n'
                    eclWatchBuildOk = False
                    
                if (len(eclWatchBuildError) > 0) and (not eclWatchBuildError.startswith('CPack:')):
                    msg += eclWatchBuildError.replace('"','').replace('u\'',  '').replace('\'','') + '\n'
                    eclWatchBuildOk = False
                    
                if len(npmInstallResultErr) > 0:
                    npmInstallResultErr = 'Install error(s): \n' + npmInstallResultErr.replace('"','').replace('u\'',  '').replace('\'','') + '\n'
                    print(npmInstallResultErr)
                    msg += npmInstallResultErr
                    eclWatchBuildOk = False
                    
                if len(npmInstallResultWarn) > 0:
                    npmInstallResultWarn = 'Install warning(s): \n' + npmInstallResultWarn.replace('"','').replace('u\'',  '').replace('\'','') + '\n'
                    print(npmInstallResultWarn)
                    msg += npmInstallResultWarn
                    
                if len(npmTestResultErr) > 0:
                    npmTestResultErr = 'Lint error(s): \n' + npmTestResultErr
                    print(npmTestResultErr)
                    msg += npmTestResultErr.replace('"','').replace('u\'',  '').replace('\'','') + '\n'
                    eclWatchBuildOk = False
                
                if len(npmTestResultWarn) > 0:
                    npmTestResultWarn = 'Lint warning(s): \n' + npmTestResultWarn
                    print(npmTestResultWarn)
                    msg += npmTestResultWarn.replace('"','').replace('u\'',  '').replace('\'','') + '\n'
                    
                if eclWatchBuildOk:
                    print("\t\tRebuild: success")
                    msg += 'Rebuild: success\n'
                else:
                    #buildFailed =  True
                    allPassed = False
                    
            msg += result
            print("\t"+result)
            continue
        elif result.startswith('HPCC Uninstall:'):
            print("\t"+result)
            msg += result
            continue
        elif result.startswith('HPCC Start: OK'):
            print("\t"+result)
            msg += result
            if runUnittests and os.path.exists('unittests.summary'):
                unittestResultFile = open('unittests.summary',  "r")
                unittestResult = unittestResultFile.readlines()
                unittestResultFile.close()
                
                # From this 'TestResult:unittest:total:87 passed:86 failed:0 timeout:1 elaps:x sec'
                # To this : (a table in github comment)
                # Unittest result:
                # |total|passed|failed|timeout|
                # |---|---|---|---|
                # |87|86|0|1|
                #
                unittestResult[0] = unittestResult[0].replace('TestResult:unittest:', 'Test:unittest ').replace('\n','').replace(' sec','_sec')
                unittestResults = unittestResult[0].split(' ')
                
                uresults={}
                table.clear()
                for res in unittestResults:
                    table.addItem(res.replace('_', ' '))
                    items = res.split(':')
                    try:
                        uresults[items[0]] = int(items[1].replace('_sec',''))
                    except ValueError as e:
                        print str(e)+"(line: "+str(inspect.stack()[0][2])+")"
                        pass
                    except KeyError as e:
                        print("items[0]:'%s', items[1]:'%s" % (items[0], items[1]))
                        print "Exception:" + str(e) + "(line: "+str(inspect.stack()[0][2]) + ")"
                        pass
                    except IndexError as e:
                        print("items[0]:'%s', items[1]:'%s" % (items[0], items[1]))
                        print "Exception:" + str(e) + "(line: "+str(inspect.stack()[0][2]) + ")"
                    except:
                        print("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
                        print("items[0]:'%s', items[1]:'%s" % (items[0], items[1]))
                            
                table.completteRow()
                
                if uresults['total'] == 0:
                    # We always run unittests, so if the total is zero that means unittests failed
                    unittestErrorLog = '\nUnittest execution error:\n```\n' + '\n'.join(unittestResult[1:]) + '```\n'
                    allPassed = False
                    pass
                elif (uresults['total'] != uresults['passed']):
                    unittestErrorLog = '\nUnittest error(s):\n```\n' + '\n'.join(unittestResult[1:]) + '```\n'
                    allPassed = False
                    pass
                    
            if runWutoolTests and os.path.exists('wutoolTests.summary'):
                wutoolTestResultFile = open('wutoolTests.summary',  "r")
                wutoolTestResult = wutoolTestResultFile.readlines()
                wutoolTestResultFile.close()
                
                # The summary can contains one or two result lines, one for Dali and one for Cassandra
                wresults=[]                
                for line in range(2):
                    if 'TestResult:wutoolTest' not in wutoolTestResult[line]:
                        break;
                    wresults.append({})
                    wutoolTestResult[line] = wutoolTestResult[line].replace('TestResult:wutoolTest', 'Test:wutoolTest').replace('):', ') ').replace('\n','').replace(' sec','_sec')
                    wutoolTestResults = wutoolTestResult[line].split(' ')
                
                    for res in wutoolTestResults:
                        table.addItem(res.replace('_', ' '))
                        items = res.split(':')
                        try:
                            wresults[line][items[0]] = int(items[1].replace('_sec',''))
                        except ValueError as e:
                            print "Exception:" + str(e) + "(line: "+str(inspect.stack()[0][2]) + ")"
                            print("items[0]:'%s', items[1]:'%s" % (items[0], items[1]))
                            pass
                        except KeyError as e:
                            print("items[0]:'%s', items[1]:'%s" % (items[0], items[1]))
                            print "Exception:" + str(e) + "(line: "+str(inspect.stack()[0][2]) + ")"
                            pass
                        except IndexError as e:
                            print("items[0]:'%s', items[1]:'%s" % (items[0], items[1]))
                            print "Exception:" + str(e) + "(line: "+str(inspect.stack()[0][2]) + ")"
                        except:
                            print("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
                            print("items[0]:'%s', items[1]:'%s" % (items[0], items[1]))
                            
                    table.completteRow()
                    pass
                
                try:
                    # We always run wutooltest, so if the total is zero for Dali (index=0) or 
                    # Dali+Cassandra (idex=1) that means wutooltest failed
                    if ((len(wresults) == 1) and ((wresults[0]['total'] != wresults[0]['passed']) or (wresults[0]['total'] == 0))) or  \
                       ((len(wresults) == 2) and ((wresults[0]['total'] != wresults[0]['passed']) or (wresults[0]['total'] == 0) or (wresults[1]['total'] != wresults[1]['passed']) or (wresults[1]['total'] == 0))):
                        errorLogStartIndex = len(wresults)
                        wutoolTestErrorLog = '\nWutool error(s):\n' + '\n'.join(wutoolTestResult[errorLogStartIndex:])
                        allPassed = False
                        pass
                except ValueError as e:
                    print "Exception:" + str(e) + "(line: "+str(inspect.stack()[0][2]) + ")"
                    pass
                except KeyError as e:
                    print "Exception:" + str(e) + "(line: "+str(inspect.stack()[0][2]) + ")"
                    pass
               
            if runUnittests or runWutoolTests:
                wutoolTestResultLog = '\nUnit tests result:\n' + table.getTable()
                wutoolTestResultLog += "\n" + unittestErrorLog.replace('"','').replace('\'','').replace('\n\n', '\n') + "\n"
                if runWutoolTests:
                    wutoolTestResultLog += wutoolTestErrorLog
                print(wutoolTestResultLog)
                msg += wutoolTestResultLog
            continue
        elif result.startswith('HPCC Start: Fail'):
            startFailed=True
            print("\t"+result)
            msg += result.replace('"','\'')
            allPassed = False
        elif result.startswith('HPCC Stop:'):
            startFailed=False
            print("\t"+result)
            msg += result
            continue
        elif result.startswith('[Error]'):
            # Suite Error
#            print("\tSuite Error"+result)
            allPassed = False
            # Prevent to add more than one '```' if multiple '[Error] row find.
            if not inSuiteErrorLog:
                suiteErrors += '```\n'
            inSuiteErrorLog = True
            suiteErrors += result
            continue
        elif inSuiteErrorLog and result.startswith('Suite destructor'):
            inSuiteErrorLog = False
            # Replace \" to \' to avoid GitHub JSON parsing error
            # and terminate GitHub code fragment tag ('```')
            msg += suiteErrors.replace('"', '\'') + ' ```\n'
            suiteErrors = ''
            continue
        elif inSuiteErrorLog:
            print("\t"+result)
            suiteErrors += result
            continue
        elif result.startswith('./ecl-test setup'):
            startFailed=False
            tempMsg = ''
            if testfiles != None:
                # This returns with processed, formated result table
                # with list of errors (if any)
                (testRes,  isCoreFlesReported) = CollectResults('HPCCSystems-regression/log', testfiles, prid)
                if not runFullRegression:
                    tempMsg = '\n'.join(testRes)
                else:
                    tempMsg = testRes
            else:
                testRes = 'No test result(s).'
                
            tempMsg = tempMsg.replace('stopped',  'stopped,')
            print("\t"+tempMsg+'\n')
            msg += "Regression test result:\n" + tempMsg+'\n'
            if ('Errors:' in msg) or ('Fail' in msg):
               testFailed=True
               allPassed = False
            continue
        elif startFailed:
            if result.startswith('Archive HPCC logs'):
                startFailed = False
                continue
            print("\t\t"+result)
            msg += result.replace('stopped',  'stopped,').replace('"','\'').replace(' \\x1b[32m ', '').replace(' \\x1b[33m ', '').replace(' \\x1b[31m ', '').replace(' \\x1b[0m', '')
            #msg += result.replace('stopped',  'stopped,').replace('[32m','').replace('[33m','').replace('[0m', '\\n').replace('[31m', '\\n').replace("\\", "").replace('\<','<').replace('/>','>').replace('\xc2\xae','').replace('/*', '*').replace('*/', '*')
            allPassed = False
            continue
        elif eclWatchBuild and not npmTest:
            if not result.startswith('---- '):
                #print(", "+result)
                result = result.replace('\n','').replace('\t','').replace('\\t','')
                items = result.split(':')
                if (len(items) >= 2) and ('errors' in items[0]) and (0 < int(items[1])):
                    allPassed = False
                    # Collect the ECLWatch build errors
                    eclWatchBuildError = 'Error(s): \n'
                    eclWatchBuildError += collectECLWatchBuildErrors()
                    continue
                
                # Old ECLWatch build result
                elif ('errors' in items[0]) or ('warnings' in items[0]) or ('build time' in items[0]):
                    eclWatchTable.addItem(result)
                    continue
                    
                #eclWatchBuildError += result + '\n'
                    
            continue
                
        elif result.startswith('npm install start'):
            if not npmInstall:
                npmInstall=True
            continue
                
        elif result.startswith('npm install end'):
            npmInstall=False
            continue
            
        elif npmInstall:
            if result.startswith('npm ERR'):
                result = result.replace('"','')
                npmInstallResultErr += result
                
            elif result.startswith('npm WARN'):
                result = result.replace('"','')
                npmInstallResultWarn += result
            
        elif result.startswith('npm test'):
            if not npmTest:
                npmTest=True
#                eclWatchBuild=True
                eclWatchTable.clear()
            else:
                npmTest=False
                eclWatchTable.completteRow()
#                msg += eclWatchTable.getTable()
#                msg += '\n'
#                if len(npmTestResultErr) > 0:
#                    print(npmTestResultErr)
#                    msg += npmTestResultErr + '\n'
            continue
        elif npmTest:
            result = result.replace('"','')
            if re.match("[1-9][0-9]* error", result):
                allPassed = False
                eclWatchBuild=True
                npmTestResultErr += result
#                items = result.split()
#                eclWatchTable.addItem("lint " + items[1]+':'+items[0])
#                #npmTestResult += 'Error(s): \n'
                
            elif result.startswith('eclwatch'):
                eclWatchBuild=True
                npmTestResultErr += result
                allPassed = False
                
            elif result.startswith('npm WARN'):
                npmTestResultWarn += result
                
            elif result.startswith('npm ERR'):
                eclWatchBuild=True
                allPassed = False
                npmTestResultErr += npmTestResult + result 

            else:
                npmTestResult += result 
        elif result.startswith('Number of core'):
            allPassed = False
            coreGenerated = True
            coreMsg = result.strip()
            continue
        elif result.startswith('time logs'):
            if not timeStats:
                timeStats=True
                timeStatsTable.clear()
            else:
                timeStats=False
                timeStatsTable.completteRow()
                timeStatsString = timeStatsTable.getTable()
                if not timeStatsString.startswith('Empty table'):
                    timeStatsString = "Time stats:\n" + timeStatsString
                    print(timeStatsString)
                    
        elif timeStats:
            items = result.replace('\n', '').split(': ')
            if len(items) == 2:
                # That was a vertical table, I think it is too big.
                #timeStatsTable.addItem('Stage:' + items[0].replace(' time', '').strip() )
                #timeStatsTable.addItem('Time: ' + items[1], ': ')
                # Create a horizontal table 
                timeStatsTable.addItem(items[0].strip() +" : " + items[1], ' : ')
            pass
            
#        if len(msg) > maxMsgLen:
#            # Too much messsages something really wrong
#            break

    # Add build error msg and link to log if happened
    if buildErrorLogAddedToGists:
        msg +=  '\n' + buildErrorStr + '\n'
    
    # add core report if there is any
    if coreGenerated:
        if not isCoreFlesReported:
            try:
                # Core files to the gists
                gistHandler = GistLogHandler(gitHubToken)
                gistHandler.createGist(prid)
                gistHandler.cloneGist()
                gistHandler.updateReadme('OS: ' + sysId + '\n')
                gistHandler.updateReadme(coreMsg + '\n')
                isCoreFlesReported = gistHandler.gistAddTraceFile()
                coreMsg = '[' + coreMsg + '](' + gistHandler.getGistUrl() + ')\n'
                gistHandler.commitAndPush()
            except ValueError as e:
                if 'token' in str(e):
                    coreMsg = str(e) + '\n'
                    coreMsg += str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")\n" 
            
        msg += coreMsg + '\n' 
            
    
    # Add timestats at the end of the report
    msg += timeStatsString
    
    if resultFile == '':
        print("\ttype(msg) is : " + repr(type(msg)))
    else:
        resultFile.write("\ttype(msg) is : " + repr(type(msg)) +"\n")

    msg = msg.replace('[32m','').replace('[33m','').replace('[0m', '\\n').replace('[31m', '\\n').replace('\<','').replace('/>','').replace('\n', '\\n') #.replace('\\xc2\\xae', '\xc2\xae')

    if type(msg) == type(u' '):
        msg = unicodedata.normalize('NFKD', msg).encode('ascii','ignore').replace('\'','').replace('\\u', '\\\\u')
        msg = repr(msg)
    else:
        msg = repr(msg)
    
    if allPassed:
        msg = msg.replace('Automated Smoketest',  'Automated Smoketest: '+ passEmoji)
    else:
        msg = msg.replace('Automated Smoketest',  'Automated Smoketest: '+ failEmoji)
    
    testInfo['status'] = str(allPassed)
    
    if resultFile == '':
        print("\tfinal type(msg) is : " + repr(type(msg)))
    else:
        resultFile.write("\tfinal type(msg) is : " + repr(type(msg)) +"\n")
        
    return msg.replace('\'', '').replace('\\\\n', '\\n')

def ProcessOpenPulls(prs,  numOfPrToTest):
    global testPrNo
    prSequnceNumber = 0
    #curDir =  os.getcwd()
    isSelectedPrOpen = False
    sortedPrs = sorted(prs)
    for prid in sortedPrs:

        if (testPrNo != str(0)):
            if testPrNo != str(prid):
                continue
            else:
                isSelectedPrOpen = True
                numOfPrToTest = 1
                    
        
        # Notify PRs behind this about their position in the queue
        # Get the index of the current
        # If there are more
        #  Loop from the next to the end and uploadGitHubComment() with position message
        index = sortedPrs.index(prid) # This is the current PR
        
        if index < numOfPrToTest - 1:
            curDir =  os.getcwd()
            prIndexInQueue = 1
            esimatedWaitingTime = prs[sortedPrs[index]]['sessionTime'] # time to complette current task
            for prIndex in range(index+1, numOfPrToTest):
                prIdInQueue = sortedPrs[prIndex]
                if prs[prIdInQueue]['inQueue']:
                    msg = "This PR (%d) is in the %d/%d position of the queue. Estimated start time is after ~%.2f hour(s)" % ( sortedPrs[prIndex], prIndexInQueue, numOfPrToTest - index - 1, esimatedWaitingTime)
                    esimatedWaitingTime += prs[prIdInQueue]['sessionTime']
                    
                    if prs[prIdInQueue]['checkBoxes']['notification']:
                        print ("notify to %d (PR-%d)" % (prIndexInQueue, sortedPrs[prIndex]))
                        print ("\t%s" % (msg) )
                        
                        addCommentCmd = prs[prIdInQueue]['addComment']['cmd'] +'\'{"body":"'+msg+'"}\' '+prs[prIdInQueue]['addComment']['url']
                        # Change to PR directory to store message ID into messageID.dat to allow to remove it after a new comment added
                        testInQueueDir = prs[prIdInQueue]['testDir']
                        os.chdir(testInQueueDir)
                        uploadGitHubComment(addCommentCmd)
                        
                        # Go back the oribinal directory
                        os.chdir(curDir)
                    else:
                        print ("do not notify to %d (PR-%d)" % (prIndexInQueue, sortedPrs[prIndex]))
                        print ("\t%s" % (msg) )
                        
                    prIndexInQueue += 1
        
        #testDir = "smoketest-"+str(prid)
        testDir = prs[prid]['testDir']
        
        testInfo = {}
        testInfo['prid'] = str(prid)
        
        # cd smoketest-<PRID>
        os.chdir(testDir)
        startTimestamp = time.time()
        curTime = time.strftime("%y-%m-%d-%H-%M-%S")
        testInfo['startTime'] = curTime
        resultFileName= "result-" + curTime + ".log"
        resultFile = open(resultFileName,  "w", 0)
        
        # First or new build
        isBuild=False
        buildFailed = False
        testFailed = False
        if not os.path.exists('build.summary') or (testPrNo == str(prid)) or ( addGitComment and not os.path.exists('messageId.dat')):
            
            # Ensure to report and use the lastes commit id
            msg = "\tGet the current commit id for PR-%d" % (prid)
            print(msg)
            resultFile.write(msg + "\n")            
            newCommitId = GetPullReqCommitId(str(prid))
            if newCommitId != '':
                prs[prid]['sha'] = newCommitId
                outFile = open('sha.dat',  "wb")
                outFile.write( prs[prid]['sha'])
                outFile.close()# store commit crc
                    
            prSequnceNumber += 1
            testPrNo  = '0'
            isBuild = True
            
            msg="Process of PR-%s, label: %s starts now.\\nThe reason of this test is: %s.\\nCommit ID: %s\\nEstimated completion time is ~%.1f hour(s)" % ( str(prid), prs[prid]['label'], prs[prid]['reason'], prs[prid]['sha'], prs[prid]['sessionTime'])
            addCommentCmd = prs[prid]['addComment']['cmd'] +'\'{"body":"'+msg+'"}\' '+prs[prid]['addComment']['url']
            
            print("\tAdd comment to pull request")
#            resultFile.write("\tAdd comment to pull request\n\tComment Cmd:\n")
#            resultFile.write("------------------------------------------------------\n")
#            resultFile.write(addCommentCmd+"\n")
#            resultFile.write("------------------------------------------------------\n")
#            if addGitComment:
            uploadGitHubComment(addCommentCmd,  resultFile)
            
            msg = "%d/%d. " % ( prSequnceNumber, numOfPrToTest) + msg.replace('\\n',' ')
            print(msg)
            print("\ttitle: %s" % (prs[prid]['title']))
            print("\tuser : %s" % (prs[prid]['user']))
            print("\tsha  : %s" % (prs[prid]['sha']))
            print("\tstart: %s" % (time.strftime("%y-%m-%d %H:%M:%S")))
            resultFile.write("%d/%d. Process PR-%s, label: %s\n" % ( prSequnceNumber, numOfPrToTest, str(prid), prs[prid]['label']))
            resultFile.write("\ttitle: %s\n" % (repr(prs[prid]['title'])))
            resultFile.write("\tsha  : %s\n" % (prs[prid]['sha']))
            resultFile.write("\tStart: %s\n" % (time.strftime("%y-%m-%d %H:%M:%S")))
            if not os.path.exists('HPCC-Platform'):
                # clone the HPCC-Platfrom directory into the smoketes-<PRID> directory
                pass
                
            print("\tcp -r HPCC-Platform %s" % (testDir))
            resultFile.write("\tcp -r HPCC-Platfrom %s\n" % (testDir))
            myProc = subprocess.Popen(["cp -fr ../HPCC-Platform ."],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            result = formatResult(myProc, resultFile)
            #resultFile.write("\tresult:"+result+"\n")

            # cd smoketest-<PRID>/HPCC-Platform
            os.chdir('HPCC-Platform')
            # Get PR branch
               
            # git remote add upstream git@github.com:hpcc-systems/HPCC-Platform.git
            print("\tAdd upstream")
            resultFile.write("\tAdd upstream\n")
            myProc = subprocess.Popen(["git remote add upstream https://" + gitHubToken + "@github.com/hpcc-systems/HPCC-Platform.git"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            result = formatResult(myProc, resultFile)
            #resultFile.write("\tresult:"+result+"\n")

            # Checkout base branch
            s = "\tbase : %s" % (prs[prid]['code_base'])
            print(s)
            resultFile.write(s + '\n')
            myProc = subprocess.Popen("git checkout -f "+prs[prid]['code_base'],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            result = formatResult(myProc, resultFile)
            #resultFile.write("\tresult:"+result+"\n")
                
            # Pull the branch
            # git fetch upstream pull/<'number'>/head:<'label'>+'-smoketest'
            print("\t"+prs[prid]['cmd'])
            resultFile.write("\tPull\n")
            resultFile.write("\t"+prs[prid]['cmd']+"\n")
            myProc = subprocess.Popen(prs[prid]['cmd'],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            (result, retcode) = formatResult(myProc, resultFile)
            if retcode != 0:
                if 'unknown option' in result:
                    print("\tThere was a problem with prevoius command, try an alternative one")
                    print("\t"+prs[prid]['cmd2'])
                    myProc = subprocess.Popen(prs[prid]['cmd2'],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                    (result, retcode) = formatResult(myProc, resultFile)
                
            if (retcode != 0) and ('Merge conflict' not in result):
                noBuildReason = "Error in git command, should skip build and test."
                resultFile.write("\tError in git command, should skip build and test.\n")
            else:    
                # Status
                print("\tgit status")
                resultFile.write("\tgit status\n")
                myProc = subprocess.Popen("git status",  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                result = formatResult(myProc, resultFile)
                noBuildReason = ""
            
            if ('Unmerged paths:' in result) or (retcode != 0):
                # There is some conflict on this branch, I think it is better to skip build and test
                if noBuildReason  == "":
                    noBuildReason = "Conflicting files, should skip build and test."
                print(noBuildReason)
                # TO-DO Should find out how to handle this situation
                isBuild = False
                
                # generate build.summary file
                os.chdir("../")
                buildSummaryFileName = 'build.summary'
                buildSummaryFile = open(buildSummaryFileName,  "wb")
                buildSummaryFile.write(noBuildReason+'\n')
                buildSummaryFile.write(result)
                buildSummaryFile.close()
                msg = "In PR-%s , label: %s : %s" % (str(prid), prs[prid]['label'], noBuildReason) 
                print(msg)
                resultFile.write(msg + "\n")
                
                msg = "Delete source directory to save disk space %s (%s)." % (testDir, prs[prid]['label'])
                print (msg)
                resultFile.write(msg + "\n")
                myProc = subprocess.Popen(["sudo rm -rf HPCC-Platform"],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                result = formatResult(myProc, resultFile)
            
                pass
            
            else:

                # Update submodule
                if prs[prid]['newSubmodule']:
                    cmd = "git submodule update --init --recursive"
                else:
                    cmd = "git submodule update --init --recursive"
                print("\t" + cmd)
                resultFile.write("\t" + cmd + "\n")
                myProc = subprocess.Popen([cmd],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                result = formatResult(myProc, resultFile)
                #resultFile.write("\tresult:"+result+"\n")

                #  git log -1 | grep '^[c]ommit' | cut  -d' ' -s -f2 >commit.crc
                
                # Check build directory
                os.chdir("../")
                if not os.path.exists('build'):
                    print("\tCreate build directory.")
                    os.mkdir('build')
                
            # Check HPCCSystems-regression directory and if it exists, archive it
            if os.path.exists('HPCCSystems-regression'):
                print("\tArchieve HPCCSystems-regression directory.")
                regressionZipFileName = 'HPCCSystems-regression-' + curTime
                zipCmd="zip -m %s -r HPCCSystems-regression/*" % (regressionZipFileName)
                print("\t%s" % (zipCmd))
                resultFile.write("\t%s" % (zipCmd))
                myProc = subprocess.Popen([ zipCmd ],  shell=True,  bufsize=-1,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                try:
                    #result = formatResult(myProc, resultFile,  noEcho)
                    result = formatResult(myProc, open(regressionZipFileName+'.log',  'w'), noEcho)
                except:
                    pass
                
            if isBuild:
                
                buildScript='build.sh'
                if useQuickBuild:
                    buildScript='quickBuild.sh'
                    
                print("\tcp -p "+smoketestHome+"/" + buildScript + " .")
                if os.path.exists("./" + buildScript):
                    os.unlink("./" + buildScript)
                resultFile.write("\tcp -p "+smoketestHome+"/" + buildScript +" .\n")
                myProc = subprocess.Popen(["cp -pf "+smoketestHome+"/" + buildScript +" ."],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                result = formatResult(myProc, resultFile)
                #resultFile.write("\tresult:"+result+"\n")
       
                testInfo['codeBase'] =  prs[prid]['code_base']
                testInfo['docsBuild'] = str(prs[prid]['isDocsChanged'])
                testInfo['runUnittests'] = str(prs[prid]['runUnittests'])
                testInfo['runWutoolTests'] = str(prs[prid]['runWutoolTests'])
                testInfo['buildEclWatch'] = str(prs[prid]['buildEclWatch'])
                
                # Build it
                # ./ build.sh
                print("\tBuild PR-"+str(prid)+", label: "+prs[prid]['label'])
                resultFile.write("\tBuild PR-"+str(prid)+", label: "+prs[prid]['label']+"\n")
                try:
                    #resultFile.write("\tscl enable devtoolset-2 "+os.getcwd()+"/build.sh " + prs[prid]['regSuiteTests'] + "\n")
                    #myProc = subprocess.Popen(["scl enable devtoolset-2 "+os.getcwd()+"/build.sh " + prs[prid]['regSuiteTests'] ],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
                    
                    cmd  = "./" + buildScript
                    cmd += " -tests='" + prs[prid]['regSuiteTests'] + "'"
                    cmd += " -docs=" +  str(prs[prid]['isDocsChanged'])
                    cmd += " -unittest=" + str(prs[prid]['runUnittests'])
                    cmd += " -wuttest=" + str(prs[prid]['runWutoolTests'])
                    cmd += " -buildEclWatch=" + str(prs[prid]['buildEclWatch'])
                    cmd += " -keepFiles=" + str(keepFiles)
                    cmd += " -enableStackTrace=" + str(prs[prid]['enableStackTrace'])
                    
                    resultFile.write("\t" + cmd + "\n")
                    myProc = subprocess.Popen([ cmd ],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
                    #myProc = subprocess.Popen(["./build.sh " + prs[prid]['regSuiteTests']  ],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
                    (myStdout,  myStderr) = myProc.communicate(input = myPassw)
                except:
                    print("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
                    pass
                #myStdout = myProc.stdout.read()
                #myStderr = myProc.stderr.read()
                result = myStdout
                
                if not myStderr.startswith('TERM'):
                    result += myStderr
                    
            else:
                result = noBuildReason
                buildFailed = True
            
            # Write out the content of "result" into buildResult-<date>.log file.
            # This file will be useful to test result/log processing without rebuild
            buildFinishedTime = time.strftime("%y-%m-%d-%H-%M-%S")
            buildResultFileName= "buildResult-" + buildFinishedTime + ".log"
            buildResultFile = open(buildResultFileName,  "w")
            buildResultFile.write(result)
            buildResultFile.close()
            
            print("\tend  : %s" % (time.strftime("%y-%m-%d %H:%M:%S")))
            
            #print("\t"+result)
            maxMsgLen = 4096
            maxLines = 60
            restMsgLen = 350
            msg= 'Automated Smoketest\n'
            msg += 'OS: ' + sysId + '\n'
            msg += 'Sha: '+prs[prid]['sha']+'\n'
            msg = processResult(result, msg, resultFile, buildFailed,  testFailed, prs[prid]['testfiles'], maxMsgLen, prs[prid]['runUnittests'], prs[prid]['runWutoolTests'], prid, prs[prid]['buildEclWatch'])
            
            
            print("\tpass : %s" % (testInfo['status']))
            
            # Avoid orphan escape '\' char.
            #while ( msg[maxMsgLen-1] == '\\' ):
            #    maxMsgLen -= 1
            
            numOfLines = msg.count('\\n')
            msgLen = len(msg)

            # Check it don't overlap if truncated!!
            if (msgLen < (2 * restMsgLen)) and (numOfLines > maxLines):
                maxLines = numOfLines
                
            if msgLen < maxMsgLen:
                maxMsgLen = msgLen
            
            print("msgLen:%d, maxMsgLen:%d, restMsgLen:%d" % (msgLen, maxMsgLen, restMsgLen))
            suffixPos = msg.find('[Build error:]')
            if  suffixPos == -1:
                suffixPos = msg.find('Time stats:')
                    
            restMsgLen = msgLen - suffixPos
            print("msgLen:%d, maxMsgLen:%d, restMsgLen:%d" % (msgLen, maxMsgLen, restMsgLen))
            
            msg = (msg[:maxMsgLen-restMsgLen] + '\\n ... ( comment is too long, '+str(numOfLines)+' lines, '+str(len(msg))+' bytes, truncated) ... \\n'+ msg[msgLen - restMsgLen:] + '```' ) if ( msgLen > maxMsgLen) or (numOfLines > maxLines) else msg

            #msg = msg.replace('stopped',  'stopped,').replace("\\", "").replace('[32m','').replace('[33m','').replace('[0m', '\\n').replace('[31m', '\\n').replace('\<','').replace('/>','').replace('\xc2\xae','')

            addCommentCmd = prs[prid]['addComment']['cmd'] +'\'{"body":"'+msg+'"}\' '+prs[prid]['addComment']['url']
            
            print("\tAdd comment to pull request")
#            resultFile.write("\tAdd comment to pull request\n\tComment Cmd:\n")
#            resultFile.write("------------------------------------------------------\n")
#            resultFile.write(addCommentCmd+"\n")
#            resultFile.write("------------------------------------------------------\n")
#            if addGitComment:
            uploadGitHubComment(addCommentCmd,  resultFile)
#            else:
#                msgId = MessageId(resultFile)
#                msgId.addNewFromResult(result)

            actDir = os.getcwd()
            if (len(prs[prid]['sourcefiles']) > 0) and isClangTidy and isBuild:
                clangTidyStart=time.time()
                print("\tExecute clang-tidy on source files:")
                resultFile.write("\tExecute clang-tidy ons ource files:\n")
                for sourceFile in prs[prid]['sourcefiles']:
                    print("\t\tExecute clang-tidy on "+sourceFile)
                    resultFile.write("\t\tExecute clang-tidy on "+sourceFile+"\n")
                    myProc = subprocess.Popen(["clang-tidy HPCC-Platform/"+sourceFile+" -p build/compile_commands.json > clang-tidy-"+os.path.basename(sourceFile).replace('.','_')+'.log'],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                    result = formatResult(myProc, resultFile)
                    #resultFile.write("\tresult:"+result+"\n")

                print("\t\tFinished. Elaps time is:" + str(time.time()-clangTidyStart)+" sec.")
                resultFile.write("\t\tFinished. Elaps time is:" + str(time.time()-clangTidyStart)+" sec\n")
            
            elapsTime = str(time.time()-startTimestamp)
            testInfo['elapsTime'] = str(elapsTime)
            testInfo['endTime'] = time.strftime("%y-%m-%d-%H-%M-%S")
            testInfo['runFullRegression'] = str(runFullRegression)
            
            storeTestInfo(smoketestHome)
            
            print("\tFinished: %s, elaps time is: %s sec" % ( time.strftime("%y-%m-%d %H:%M:%S"), str(elapsTime) ))
            resultFile.write("\tFinished: %s, elaps time is: %s sec" % ( time.strftime("%y-%m-%d %H:%M:%S"), str(elapsTime) ))
            # Create a PR related directory called 'PR<PRID>' for 
            #       - build
            #       - archives
            #       - results
            #       - logs
            #       - ecl testcases, keys subdirectories
            
            # Check out this new smoketest branch (if the pull doesn't do that)
            
            # Start a thread to build it in the directory created earlier
            
            # Start a thread to generate smoke test suite
            # Get the name of the changed sourcefiles and possible the changes/diff to get function name(s)
            # 1. query the source files/function names to get regression suite test name(s) and completion times
            # 2. build a list and ensure all source testing at least once, if the commulative execution time for selected test cases less than the limit add more test cases
            # 3. Copy selected testcases into a separate directory and wait for 2. finished
            # 4. Generate a new config file called  'smoketest-<PRID>.json' which is 
            #           - points to het new smoketest ecl directory
            #           - set all other directory to a smoke test specific ones
            #           - set timeout to the limit (in 2.) and execute ecl-test
            
            # Build it
            
            # Report the result
            
        else:
            myPrint("PR-"+str(prid)+", label: "+prs[prid]['label']+ ' already tested!')
            resultFile.write("PR-"+str(prid)+", label: "+prs[prid]['label']+ ' already tested!\n')

        if (not keepFiles) and ((not testFailed) and (not buildFailed) and (os.path.exists('build') or os.path.exists('HPCC-Platform') or os.path.exists('hpcc'))):
            # remove build files to free disk space
            print("Move hpcc package out from buld directory")
            resultFile.write("Move hpcc package out from buld directory\n")
            myProc = subprocess.Popen(["mv build/hpccsystems-platform* ."],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            result = formatResult(myProc, resultFile)
            #resultFile.write("\tresult:"+result+"\n")
            
            print ("Delete source and build directory to save disk space "+testDir+" ("+prs[prid]['label']+").")
            resultFile.write("Delete source and build directory to save disk space "+testDir+" ("+prs[prid]['label']+").\n")
            myProc = subprocess.Popen(["sudo rm -rf HPCC-Platform build hpcc"],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            result = formatResult(myProc, resultFile)
            #resultFile.write("\tresult:"+result+"\n")
              
        endTimestamp = time.time()
        myPrint("\tElapsed time:"+str(endTimestamp-startTimestamp)+" sec.")
        resultFile.write("\tElapsed time:"+str(endTimestamp-startTimestamp)+" sec.\n")
        
        resultFile.close()
#        if not isBuild and os.path.exists(resultFileName):
#            os.unlink(resultFileName)
        
        os.chdir(smoketestHome)
        
        if testOnlyOnePR:
            print("It was one PR build attempt.")
            break;
    if (testPrNo != str(0)) and not isSelectedPrOpen:
        if skipDraftPr and (testPrNo != str(prid)):
            print("\nThe PR-%s is in draft state and testing a draft PR is disabled." % (testPrNo))
        else:
            print("\nIt seems the PR-%s is already closed." % (testPrNo))
        
    os.chdir(cwd)
    
def HandleSkippedPulls(prSkipped):
    curDir =  os.getcwd()
    sortedPrs = sorted(prSkipped)
    for prid in sortedPrs:
        print("Handle skipped PR-%s" % (prid))
        testDir = prSkipped[prid]['testDir']
        if not os.path.exists(testDir):
            os.mkdir(testDir)
        
        os.chdir(testDir)
        #startTimestamp = time.time()
        isAlreadyCommented = True
        if not os.path.exists('build.summary'):
            print("build.summary not exists in %s." % (testDir))
            buildSummary = open('build.summary', "w")
            buildSummary.write("Skipped");
            buildSummary.close()
            isAlreadyCommented =  False
        else:
            print("build.summary exists.")
            #resultFile.write(msg + "\n")            
                            
            buildSummary = open('build.summary', "r")
            lines = buildSummary.readline()
            buildSummary.close()
            if "Skipped" in lines:
                print("Already '%s'." % (lines))
                # Check the sha.dat
                shaFile = open('sha.dat',  "rb")
                sha = shaFile.readline()
                shaFile.close()
                if sha != prSkipped[prid]['sha']:
                    print("Old commit id (%s) and the current (%s) is not match." % (sha, prSkipped[prid]['sha']))
                    # There is a new comit store its id add comment the PR again 
                    outFile = open('sha.dat',  "wb")
                    outFile.write( prSkipped[prid]['sha'])
                    outFile.close()# store commit crc
                    isAlreadyCommented =  False
                    # Update build.summary timestamps with 'touch' command
                    print("Update build.summary timestamp")
                    myProc = subprocess.Popen(["touch build.summary"],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                    result = formatResult(myProc, None)
                    
            else:
                print("build.summary exists in %s but it's content not as expected. Correct it." % (testDir))
                buildSummary = open('build.summary', "w")
                buildSummary.write("Skipped");
                buildSummary.close()
                isAlreadyCommented =  False
        
        if  not isAlreadyCommented:
            msg="Process of PR-%s, label: %s is skipped.\\nThe reason is: It is related to containerised environment only.\\nCommit ID: %s\\nOS: %s" % ( str(prid), prSkipped[prid]['label'], prSkipped[prid]['sha'],  sysId.replace('\n', '\\n'))
            addCommentCmd = prSkipped[prid]['addComment']['cmd'] +'\'{"body":"'+msg+'"}\' '+prSkipped[prid]['addComment']['url']
                
#            resultFile.write("\tAdd comment to pull request\n\tComment Cmd:\n")
#            resultFile.write("------------------------------------------------------\n")
#            resultFile.write(addCommentCmd+"\n")
#            resultFile.write("------------------------------------------------------\n")
            if addGitComment:
                print("\tAdd comment to pull request")
                uploadGitHubComment(addCommentCmd)
            else:
                print("\tGitHub commenting disabled")
        else:
            print("\tAlready commented as 'Skipped'.")
    
        os.chdir(curDir)
    
    print("\n")    
    pass
    
def consumerTask(prId, pr, cmd, testInfo, resultFileName):
    resultFile = open(resultFileName,  "a", 0)
    cwd = os.getcwd()
    print("cmd:'%s', cwd: %s" % (cmd,  cwd))
    testInfo['codeBase'] =  prs[prId]['code_base']
    testInfo['docsBuild'] = str(prs[prId]['isDocsChanged'])
    testInfo['runUnittests'] = str(prs[prId]['runUnittests'])
    testInfo['runWutoolTests'] = str(prs[prId]['runWutoolTests'])
    testInfo['buildEclWatch'] = str(prs[prId]['buildEclWatch'])
    
    retcode='0'
    try:
        myProc = subprocess.Popen([ cmd ],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
        (result,  retcode) = formatResult(myProc, resultFile, False)
    except:
        msg = "Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" 
        print(msg)
        resultFile.write(msg + '\n')
        pass
        
    # End game
    elapsTime = str(time.time()-testInfo['startTimestamp'])
    testInfo['elapsTime'] = str(elapsTime)
    testInfo['endTime'] = time.strftime("%y-%m-%d-%H-%M-%S")
    testInfo['runFullRegression'] = str(runFullRegression)

    storeTestInfo(smoketestHome, testInfo)
    
#    # Generate fake build.summary for testing purpose only
#    buildSummaryFileName = smoketestHome + '/' + threading.current_thread().name + '/build.summary'
#    buildSummaryFile = open(buildSummaryFileName,  "wb")
#    buildSummaryFile.write('Build: success\n')
#    buildSummaryFile.close()
    
    resultFile.close()
    print("[%s] finished with retCode: %s." % (threading.current_thread().name, retcode ))
    
def ScheduleOpenPulls(prs,  numOfPrToTest):
    global testPrNo
    testPrNoId = int(testPrNo)
    prSequnceNumber = 0
    #curDir =  os.getcwd()
    isSelectedPrOpen = False
    sortedPrs = sorted(prs)
    for prid in sortedPrs:

        if testPrNoId != 0:
            if testPrNoId != prid:
                continue
            else:
                isSelectedPrOpen = True
                numOfPrToTest = 1
                    
        
        # Notify PRs behind this about their position in the queue
        # Get the index of the current
        # If there are more
        #  Loop from the next to the end and uploadGitHubComment() with position message
#        index = sortedPrs.index(prid) # This is the current PR
#        
#        if index < numOfPrToTest - 1:
#            curDir =  os.getcwd()
#            prIndexInQueue = 1
#            esimatedWaitingTime = prs[sortedPrs[index]]['sessionTime'] # time to complette current task
#            for prIndex in range(index+1, numOfPrToTest):
#                prIdInQueue = sortedPrs[prIndex]
#                if prs[prIdInQueue]['inQueue']:
#                    msg = "This PR (%d) is in the %d/%d position of the queue. Estimated start time is after ~%.2f hour(s)" % ( sortedPrs[prIndex], prIndexInQueue, numOfPrToTest - index - 1, esimatedWaitingTime)
#                    esimatedWaitingTime += prs[prIdInQueue]['sessionTime']
#                    
#                    if prs[prIdInQueue]['checkBoxes']['notification']:
#                        print ("notify to %d (PR-%d)" % (prIndexInQueue, sortedPrs[prIndex]))
#                        print ("\t%s" % (msg) )
#                        
#                        addCommentCmd = prs[prIdInQueue]['addComment']['cmd'] +'\'{"body":"'+msg+'"}\' '+prs[prIdInQueue]['addComment']['url']
#                        # Change to PR directory to store message ID into messageID.dat to allow to remove it after a new comment added
#                        testInQueueDir = prs[prIdInQueue]['testDir']
#                        os.chdir(testInQueueDir)
#                        uploadGitHubComment(addCommentCmd)
#                        
#                        # Go back the oribinal directory
#                        os.chdir(curDir)
#                    else:
#                        print ("do not notify to %d (PR-%d)" % (prIndexInQueue, sortedPrs[prIndex]))
#                        print ("\t%s" % (msg) )
#                        
#                    prIndexInQueue += 1
        
        #testDir = "smoketest-"+str(prid)
        testDir = prs[prid]['testDir']
        
        # cd smoketest-<PRID>
        os.chdir(testDir)
        startTimestamp = time.time()
#        curTime = time.strftime("%y-%m-%d-%H-%M-%S")
#        resultFileName= "scheduler-" + curTime + ".log"
#        resultFile = open(resultFileName,  "a", 0)
        
        # First or new build
        isBuild=False
        buildFailed = False
        testFailed = False
        if not os.path.exists('build.summary') or (testPrNoId == prid) or ( addGitComment and not os.path.exists('messageId.dat')):
            
#            # Ensure to report and use the lastes commit id
#            msg = "\tGet the current commit id for PR-%d" % (prid)
#            print(msg)
#            resultFile.write(msg + "\n")            
#            newCommitId = GetPullReqCommitId(str(prid))
#            if newCommitId != '':
#                prs[prid]['sha'] = newCommitId
#                outFile = open('sha.dat',  "wb")
#                outFile.write( prs[prid]['sha'])
#                outFile.close()# store commit crc
#                    
            prSequnceNumber += 1
            testPrNo  = '0'
            isBuild = True
            
            msg="Process of PR-%s, label: %s starts now.\\nThe reason of this test is: %s.\\nCommit ID: %s\\nEstimated completion time is ~%.1f hour(s)\\nOS: %s" % ( str(prid), prs[prid]['label'], prs[prid]['reason'], prs[prid]['sha'], prs[prid]['sessionTime'], sysId.replace('\n', '\\n'))
            addCommentCmd = prs[prid]['addComment']['cmd'] +'\'{"body":"'+msg+'"}\' '+prs[prid]['addComment']['url']
            
            print("\tAdd comment to pull request")
#            resultFile.write("\tAdd comment to pull request\n\tComment Cmd:\n")
#            resultFile.write("------------------------------------------------------\n")
#            resultFile.write(addCommentCmd+"\n")
#            resultFile.write("------------------------------------------------------\n")
#            if addGitComment:
            #uploadGitHubComment(addCommentCmd,  resultFile)
            
            msg = "%d/%d. " % ( prSequnceNumber, numOfPrToTest) + msg.replace('\\n',' ')
            print(msg)
            print("\tuser : %s" % (prs[prid]['user']))
            
#            resultFile.write("%d/%d. Process PR-%s, label: %s\n" % ( prSequnceNumber, numOfPrToTest, str(prid), prs[prid]['label']))
#            resultFile.write("\ttitle: %s\n" % (repr(prs[prid]['title'])))
#            resultFile.write("\tsha  : %s\n" % (prs[prid]['sha']))
            
            if not os.path.exists('HPCC-Platform'):
                # clone the HPCC-Platfrom directory into the smoketes-<PRID> directory
                pass
                
            # Not necessary, because build will be happened on the AWS instance
#            print("\tcp -r HPCC-Platform %s" % (testDir))
#            resultFile.write("\tcp -r HPCC-Platfrom %s\n" % (testDir))
#            myProc = subprocess.Popen(["cp -fr ../HPCC-Platform ."],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#            result = formatResult(myProc, resultFile)
#            #resultFile.write("\tresult:"+result+"\n")
#
#            # cd smoketest-<PRID>/HPCC-Platform
#            os.chdir('HPCC-Platform')
#            # Get PR branch
#               
#            # git remote add upstream git@github.com:hpcc-systems/HPCC-Platform.git
#            print("\tAdd upstream")
#            resultFile.write("\tAdd upstream\n")
#            myProc = subprocess.Popen(["git remote add upstream https://" + gitHubToken + "@github.com/hpcc-systems/HPCC-Platform.git"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#            result = formatResult(myProc, resultFile)
#            #resultFile.write("\tresult:"+result+"\n")
#
#            # Checkout base branch
#            s = "\tbase : %s" % (prs[prid]['code_base'])
#            print(s)
#            resultFile.write(s + '\n')
#            myProc = subprocess.Popen("git checkout -f "+prs[prid]['code_base'],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#            result = formatResult(myProc, resultFile)
#            #resultFile.write("\tresult:"+result+"\n")
#                
#            # Pull the branch
#            # git fetch upstream pull/<'number'>/head:<'label'>+'-smoketest'
#            print("\t"+prs[prid]['cmd'])
#            resultFile.write("\tPull\n")
#            resultFile.write("\t"+prs[prid]['cmd']+"\n")
#            myProc = subprocess.Popen(prs[prid]['cmd'],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#            (result, retcode) = formatResult(myProc, resultFile)
#            if retcode != 0:
#                if 'unknown option' in result:
#                    print("\tThere was a problem with prevoius command, try an alternative one")
#                    print("\t"+prs[prid]['cmd2'])
#                    myProc = subprocess.Popen(prs[prid]['cmd2'],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#                    (result, retcode) = formatResult(myProc, resultFile)
#                
#            if retcode != 0:
#                noBuildReason = "Error in git command, should skip build and test."
#            else:    
#                # Status
#                print("\tgit status")
#                resultFile.write("\tgit status\n")
#                myProc = subprocess.Popen("git status",  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#                result = formatResult(myProc, resultFile)
#                noBuildReason = ""
#            
#            if ('Unmerged paths:' in result) or (retcode != 0):
#                # There is some conflict on this branch, I think it is better to skip build and test
#                if noBuildReason  == "":
#                    noBuildReason = "Conflicting files, should skip build and test."
#                print(noBuildReason)
#                # TO-DO Should find out how to handle this situation
#                isBuild = False
#                
#                # generate build.summary file
#                os.chdir("../")
#                buildSummaryFileName = 'build.summary'
#                buildSummaryFile = open(buildSummaryFileName,  "wb")
#                buildSummaryFile.write(noBuildReason+'\n')
#                buildSummaryFile.write(result)
#                buildSummaryFile.close()
#                msg = "In PR-%s , label: %s : %s" % (str(prid), prs[prid]['label'], noBuildReason) 
#                print(msg)
#                resultFile.write(msg + "\n")
#                
#                msg = "Delete source directory to save disk space %s (%s)." % (testDir, prs[prid]['label'])
#                print (msg)
#                resultFile.write(msg + "\n")
#                myProc = subprocess.Popen(["sudo rm -rf HPCC-Platform"],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#                result = formatResult(myProc, resultFile)
#            
#                pass
#            
#            else:
#
#                # Update submodule
#                if prs[prid]['newSubmodule']:
#                    cmd = "git submodule update --init --recursive"
#                else:
#                    cmd = "git submodule update --init --recursive"
#                print("\t" + cmd)
#                resultFile.write("\t" + cmd + "\n")
#                myProc = subprocess.Popen([cmd],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#                result = formatResult(myProc, resultFile)
#                #resultFile.write("\tresult:"+result+"\n")
#
#                #  git log -1 | grep '^[c]ommit' | cut  -d' ' -s -f2 >commit.crc
#                
#                # Check build directory
#                os.chdir("../")
#                if not os.path.exists('build'):
#                    print("\tCreate build directory.")
#                    os.mkdir('build')
#                
#            # Check HPCCSystems-regression directory and if it exists, archive it
#            if os.path.exists('HPCCSystems-regression'):
#                print("\tArchieve HPCCSystems-regression directory.")
#                regressionZipFileName = 'HPCCSystems-regression-' + curTime
#                zipCmd="zip -m %s -r HPCCSystems-regression/*" % (regressionZipFileName)
#                print("\t%s" % (zipCmd))
#                resultFile.write("\t%s" % (zipCmd))
#                myProc = subprocess.Popen([ zipCmd ],  shell=True,  bufsize=-1,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#                try:
#                    #result = formatResult(myProc, resultFile,  noEcho)
#                    result = formatResult(myProc, open(regressionZipFileName+'.log',  'w'), noEcho)
#                except:
#                    pass
#                
            key = str(prid)
            if key in threads: 
                if threads[key]['thread'].is_alive():
                    elaps = time.time()-threads[key]['startTimestamp']
                    print("--- PR-%s (%s) is scheduled and active. (started at: %s, elaps: %d sec, %d min))"  % (key, threads[key]['commitId'], threads[key]['startTime'], elaps,  elaps / 60 ) )
                else:
                    print("--- PR-%s (%s) is scheduled but already finished. Remove"  % (key, threads[key]['commitId']))
                    del threads[key]
            
            if not key in threads:
                print("\tsha  : %s" % (prs[prid]['sha'][0:8].upper() ))
                print("\tstart: %s" % (time.strftime("%y-%m-%d %H:%M:%S")))
                print("\ttitle: %s" % (prs[prid]['title']))
                curTime = time.strftime("%y-%m-%d-%H-%M-%S")
                resultFileName= "scheduler-" + curTime + ".test"
                resultFile = open(resultFileName,  "a", 0)
                resultFile.write("\tStart: %s\n" % (time.strftime("%y-%m-%d %H:%M:%S")))
                testInfo = {}
                testInfo['prid'] = str(prid)
                testInfo['startTime'] = curTime
                testInfo['startTimestamp'] = time.time()
                testInfo['commitId'] = prs[prid]['sha'][0:8].upper()
                # Schedule it
                print("\tSchedule PR-"+str(prid)+", label: "+prs[prid]['label'])
                resultFile.write("\tSchedule PR-"+str(prid)+", label: "+prs[prid]['label']+"\n")
                resultFile.write("%d/%d. Process PR-%s, label: %s\n" % ( prSequnceNumber, numOfPrToTest, str(prid), prs[prid]['label']))
                resultFile.write("\ttitle: %s\n" % (repr(prs[prid]['title'])))
                resultFile.write("\tsha  : %s\n" % (prs[prid]['sha']))
                
                try:
                    buildScript='manageInstance.sh'
                    cmd  = smoketestHome + "/" + buildScript
                    cmd += " -instanceName='" + "PR-" + key + "'"
                    cmd += " -smoketestHome='" + smoketestHome + "'"
                    cmd += " -addGitComment=" + str(addGitComment)
#                    cmd += " -tests='" + prs[prid]['regSuiteTests'] + "'"
                    cmd += " -docs=" +  str(prs[prid]['isDocsChanged'])
                    cmd += " -commitId=" + prs[prid]['sha'][0:8].upper() 
#                    cmd += " -unittest=" + str(prs[prid]['runUnittests'])
#                    cmd += " -wuttest=" + str(prs[prid]['runWutoolTests'])
#                    cmd += " -buildEclWatch=" + str(prs[prid]['buildEclWatch'])
#                    cmd += " -keepFiles=" + str(keepFiles)
#                    cmd += " -enableStackTrace=" + str(prs[prid]['enableStackTrace'])
                    cmd += " -appId='" + appId + "'"
                    
                    resultFile.write("\t" + cmd + "\n")
                 
                    threads[key] =  prs[prid]
                    threads[key]['thread'] = threading.Thread(target=consumerTask, name="PR-" + key, args=(prid, prs[prid], cmd, testInfo, resultFileName))
                    threads[key]['thread'].daemon = True
                    threads[key]['thread'].start()
                    threads[key]['startTime'] = curTime
                    threads[key]['startTimestamp'] = time.time()
                    threads[key]['resultFileName'] = resultFileName
                    threads[key]['commitId'] = testInfo['commitId']
                    print("--- Scheduled, new (key:%s)"  % (key))
                    print("\tend  : %s" % (time.strftime("%y-%m-%d %H:%M:%S")))

                    elapsTime = str(time.time()-startTimestamp)
                    print("\tFinished: %s, elaps time is: %s sec" % ( time.strftime("%y-%m-%d %H:%M:%S"), str(elapsTime) ))
                    resultFile.write("\tFinished: %s, elaps time is: %s sec" % ( time.strftime("%y-%m-%d %H:%M:%S"), str(elapsTime) ))

                except:
                    print("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
                    pass
                    
                resultFile.close()
                
#                #myStdout = myProc.stdout.read()
#                #myStderr = myProc.stderr.read()
#                result = myStdout
                
#                if not myStderr.startswith('TERM'):
#                    result += myStderr
                
            
#            # Write out the content of "result" into buildResult-<date>.log file.
#            # This file will be useful to test result/log processing without rebuild
#            buildFinishedTime = time.strftime("%y-%m-%d-%H-%M-%S")
#            buildResultFileName= "buildResult-" + buildFinishedTime + ".log"
#            buildResultFile = open(buildResultFileName,  "w")
#            buildResultFile.write(result)
#            buildResultFile.close()
#            
#            #print("\t"+result)
#            maxMsgLen = 4096
#            maxLines = 60
#            restMsgLen = 350
#            msg= 'Automated Smoketest\n'
#            msg += 'OS: ' + sysId + '\n'
#            msg += 'Sha: '+prs[prid]['sha']+'\n'
#            msg = processResult(result, msg, resultFile, buildFailed,  testFailed, prs[prid]['testfiles'], maxMsgLen, prs[prid]['runUnittests'], prs[prid]['runWutoolTests'], prid, prs[prid]['buildEclWatch'])
#            
#            
#            print("\tpass : %s" % (testInfo['status']))
#            
#            # Avoid orphan escape '\' char.
#            #while ( msg[maxMsgLen-1] == '\\' ):
#            #    maxMsgLen -= 1
#            
#            numOfLines = msg.count('\\n')
#            msgLen = len(msg)
#
#            # Check it don't overlap if truncated!!
#            if (msgLen < (2 * restMsgLen)) and (numOfLines > maxLines):
#                maxLines = numOfLines
#                
#            if msgLen < maxMsgLen:
#                maxMsgLen = msgLen
#            
#            print("msgLen:%d, maxMsgLen:%d, restMsgLen:%d" % (msgLen, maxMsgLen, restMsgLen))
#            suffixPos = msg.find('[Build error:]')
#            if  suffixPos == -1:
#                suffixPos = msg.find('Time stats:')
#                    
#            restMsgLen = msgLen - suffixPos
#            print("msgLen:%d, maxMsgLen:%d, restMsgLen:%d" % (msgLen, maxMsgLen, restMsgLen))
#            
#            msg = (msg[:maxMsgLen-restMsgLen] + '\\n ... ( comment is too long, '+str(numOfLines)+' lines, '+str(len(msg))+' bytes, truncated) ... \\n'+ msg[msgLen - restMsgLen:] + '```' ) if ( msgLen > maxMsgLen) or (numOfLines > maxLines) else msg
#
#            #msg = msg.replace('stopped',  'stopped,').replace("\\", "").replace('[32m','').replace('[33m','').replace('[0m', '\\n').replace('[31m', '\\n').replace('\<','').replace('/>','').replace('\xc2\xae','')
#
#            addCommentCmd = prs[prid]['addComment']['cmd'] +'\'{"body":"'+msg+'"}\' '+prs[prid]['addComment']['url']
#            
#            print("\tAdd comment to pull request")
##            resultFile.write("\tAdd comment to pull request\n\tComment Cmd:\n")
##            resultFile.write("------------------------------------------------------\n")
##            resultFile.write(addCommentCmd+"\n")
##            resultFile.write("------------------------------------------------------\n")
##            if addGitComment:
#            uploadGitHubComment(addCommentCmd,  resultFile)
##            else:
##                msgId = MessageId(resultFile)
##                msgId.addNewFromResult(result)
#
#            actDir = os.getcwd()
#            if (len(prs[prid]['sourcefiles']) > 0) and isClangTidy and isBuild:
#                clangTidyStart=time.time()
#                print("\tExecute clang-tidy on source files:")
#                resultFile.write("\tExecute clang-tidy ons ource files:\n")
#                for sourceFile in prs[prid]['sourcefiles']:
#                    print("\t\tExecute clang-tidy on "+sourceFile)
#                    resultFile.write("\t\tExecute clang-tidy on "+sourceFile+"\n")
#                    myProc = subprocess.Popen(["clang-tidy HPCC-Platform/"+sourceFile+" -p build/compile_commands.json > clang-tidy-"+os.path.basename(sourceFile).replace('.','_')+'.log'],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#                    result = formatResult(myProc, resultFile)
#                    #resultFile.write("\tresult:"+result+"\n")
#
#                print("\t\tFinished. Elaps time is:" + str(time.time()-clangTidyStart)+" sec.")
#                resultFile.write("\t\tFinished. Elaps time is:" + str(time.time()-clangTidyStart)+" sec\n")
#            
            
            # Create a PR related directory called 'PR<PRID>' for 
            #       - build
            #       - archives
            #       - results
            #       - logs
            #       - ecl testcases, keys subdirectories
            
            # Check out this new smoketest branch (if the pull doesn't do that)
            
            # Start a thread to build it in the directory created earlier
            
            # Start a thread to generate smoke test suite
            # Get the name of the changed sourcefiles and possible the changes/diff to get function name(s)
            # 1. query the source files/function names to get regression suite test name(s) and completion times
            # 2. build a list and ensure all source testing at least once, if the commulative execution time for selected test cases less than the limit add more test cases
            # 3. Copy selected testcases into a separate directory and wait for 2. finished
            # 4. Generate a new config file called  'smoketest-<PRID>.json' which is 
            #           - points to het new smoketest ecl directory
            #           - set all other directory to a smoke test specific ones
            #           - set timeout to the limit (in 2.) and execute ecl-test
            
            # Build it
            
            # Report the result
            
        else:
            myPrint("PR-"+str(prid)+", label: "+prs[prid]['label']+ ' already tested!')
#            resultFile.write("PR-"+str(prid)+", label: "+prs[prid]['label']+ ' already tested!\n')

#        if (not keepFiles) and ((not testFailed) and (not buildFailed) and (os.path.exists('build') or os.path.exists('HPCC-Platform') or os.path.exists('hpcc'))):
#            # remove build files to free disk space
#            print("Move hpcc package out from buld directory")
#            resultFile.write("Move hpcc package out from buld directory\n")
#            myProc = subprocess.Popen(["mv build/hpccsystems-platform* ."],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#            result = formatResult(myProc, resultFile)
#            #resultFile.write("\tresult:"+result+"\n")
#            
#            print ("Delete source and build directory to save disk space "+testDir+" ("+prs[prid]['label']+").")
#            resultFile.write("Delete source and build directory to save disk space "+testDir+" ("+prs[prid]['label']+").\n")
#            myProc = subprocess.Popen(["sudo rm -rf HPCC-Platform build hpcc"],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#            result = formatResult(myProc, resultFile)
#            #resultFile.write("\tresult:"+result+"\n")
              
        endTimestamp = time.time()
        myPrint("\tElapsed time:"+str(endTimestamp-startTimestamp)+" sec.")
#        resultFile.write("\tElapsed time:"+str(endTimestamp-startTimestamp)+" sec.\n")
        
#        resultFile.close()
#        if not isBuild and os.path.exists(resultFileName):
#            os.unlink(resultFileName)
        
        os.chdir(smoketestHome)
        
        if testOnlyOnePR:
            print("It was one PR build attempt.")
            break;
            
    # TODO this must sorted out
    if (testPrNoId != 0) and not isSelectedPrOpen:
        if skipDraftPr and (testPrNoId != prid):
            print("\nThe PR-%s is in draft state and testing a draft PR is disabled." % (testPrNoId))
        else:
            print("\nIt seems the PR-%s is skipped or draft or already closed." % (testPrNoId))
        
    # Until this point all open PR is checked/scheduled
    isNotThere = True
    print("[%s] - Check if there is any closed but still running task..." % (threading.current_thread().name))
    for key in sorted(threads):
        if threads[key]['thread'].is_alive():
            if (int(key) not in sortedPrs):
                elaps = time.time()-threads[key]['startTimestamp']
                print("--- PR-%s (%s) is closed but scheduled and active. (started at: %s, elaps: %d sec, %d min))"  % (key, threads[key]['commitId'], threads[key]['startTime'], elaps,  elaps / 60 ) )
                isNotThere = False
    if isNotThere:
        print("[%s] - None\n" % (threading.current_thread().name))
    else:
        print("[%s] - End of list\n" % (threading.current_thread().name))
        
    os.chdir(cwd)


def storeTestInfo(path, testInfo):
    print(testInfo)
    smoketestInfoFileName = path+'/SmoketestInfo.csv'
    smoketestInfoFile = open(smoketestInfoFileName ,  "a")
    separator = ''
    for item in testInfo:
        smoketestInfoFile.write("%s%s:%s" % (separator,  item,  testInfo[item]))
        separator = ','
        
    smoketestInfoFile.write("\n")
    smoketestInfoFile.close

#
#-----------------------------------------------------------------
#
# Github Pr messages handling
# Remove previous message to decrease the noise of smoketest
#
class MessageId(object):
    messageIds=[]
    messageIdsFile='messageId.dat'
    prId = None

    def __init__(self,  resultFile):
        self.resultFile = resultFile
        self.last = -1
        if os.path.exists( self.messageIdsFile ):
            file = open(self.messageIdsFile ,  "r") 
            for line in file:
                self.messageIds.append( line.strip().replace('\n',''))
            file.close()
            self.last = len(self.messageIds) - 1
        pass

    def __str__(self):
        retVal = ''
        if len(self.messageIds) > 0:
            for msgId in self.messageIds:
                retVal += msgId+'\n'
        else:
            retVal = '(empty)'

        return retVal
        pass


    def getLast(self):
        retVal = 'None'
        if self.last > -1:
            retVal = self.messageIds[self.last]
        return retVal
        pass

    def addNew(self,  messageId):
        self.messageIds.append(messageId)
        file = open(self.messageIdsFile ,  "a")
        file.write(messageId+'\n')
        file.close()
        pass

    def addNewFromResult(self,  result):
        messageId = None
        results = result.split('\n')
        for line in results:
            line = line.strip()
            if line.startswith('"id":'):
                messageId= line.split(':')[1].strip(',').strip()
                break
        if messageId == None:
            return
        self.addNew(messageId)
        self.removeLastMsgFromGithub()
        self.last += 1
        pass
        
    def removeLastMsgFromGithub(self):
        last = self.getLast()
        if not last == 'None':
            if os.path.exists( 'gistsItems.dat'):
                try:
                    # remove all old uploaded gists items first
                    gistHandler = GistLogHandler(gitHubToken)
                    gistHandler.removeGists()
                except ValueError as e:
                    if 'token' in str(e):
                        gistsRemoveErrorMsg = str(e) + '\n'
                        gistsRemoveErrorMsg += '\t' + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")\n" 
                        self.resultFile.write("\t%s\n" % (gistsRemoveErrorMsg))
                        
            elif self.resultFile != None:
                self.resultFile.write("\tThere is no related gist\n")
                
            # Now remove old message
            cmd = 'curl -H "Content-Type: application/json" -H "Authorization: token ' + gitHubToken + '"  --request DELETE https://api.github.com/repos/hpcc-systems/HPCC-Platform/issues/comments/'+last
            if self.resultFile != None:
                self.resultFile.write("\tcmd:"+cmd + "\n")
                
            myProc = subprocess.Popen(cmd,  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            (result, retcode) = formatResult(myProc)
            if self.resultFile != None:
                self.resultFile.write("\tresult"+result + "\n")
        

def uploadGitHubComment(addCommentCmd,  resultFile = None):
    def resultFileWrite(logline):
        if resultFile != None:
            resultFile.write(logline)
    
    if resultFile != None:
        resultFile.write("\tAdd comment to pull request\n\tComment Cmd:\n")
        resultFile.write("------------------------------------------------------\n")
        resultFile.write(addCommentCmd+"\n")
        resultFile.write("------------------------------------------------------\n")
    
    if not addGitComment:
            return

    attempts = 2
    while attempts:
        attempts -= 1
        myProc = subprocess.Popen(addCommentCmd,  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#                    result = myProc.stdout.read() + myProc.stderr.read()
#                    print("\t"+result)
#                    resultFile.write("\tresult:"+result+"\n")
        (result, retcode) = formatResult(myProc)
        resultFileWrite("\tresult:"+result+"\n")

        if 'created_at' in result:
            print("\tComment added.")
            resultFileWrite("\tComment added.\n")
            msgId = MessageId(resultFile)
            msgId.addNewFromResult(result)
            break

        elif 'Problems parsing JSON' in result:
            print("\n\t  !!!! Malformed message body! Should check!!!!\n")
            resultFileWrite("\n\t  !!!! Malformed message body! Should check!!!!\n")
            break
        
        elif 'curl: (6)' in result:
            if attempts:
                print("\tcurl connection error, try again")
                resultFileWrite("\tcurl connection error, try again\n")

                # wait for a while to next attempt
                time.sleep(30)
            else:
                print("\tAttempts exhausted, give up")
                resultFileWrite("\tAttempts exhausted, give up\n")

#
#
#----------------------------------------------------------------
# Signal handling
#

def handler(signum, frame=None):
    msg = "Signal handler called with " + str(signum)

    if signum == signal.SIGALRM:
        msg +=", SIGALRM"

    elif signum == signal.SIGTERM:
        msg += ", SIGTERM"

    elif signum == signal.SIGKILL:
        msg +=", SIGKILL"
        msg +="\nDone\nDone, exit.\n"

    elif signum == signal.SIGINT:
        msg += ", SIGINT (Ctrl+C)"

    else:
        msg += ", ?"

    print(msg)
    print("Interrupted at " + time.asctime())
    print("-------------------------------------------------\n")
    exit()

def on_exit(sig=None, func=None):
    handler(signal.SIGKILL)
    
def checkClangTidy():
    # Check if clang-tidy is installed
    # type "clang-tidy" 2>&1 | grep -c "clang-tidy is"
    # 1 if yes
    # 0 if not
    myProc = subprocess.Popen(['type "clang-tidy" 2>&1 | grep -c "clang-tidy is"'],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
    (myStdout,  myStderr) = myProc.communicate()
    result = myStdout+ myStderr
    return int(result)
    
def cleanUp(smoketestHome):
    os.chdir(smoketestHome)
    print("cleanUp()\ncwd:" +  os.getcwd())
    try:
#        oldPRsDir='OldPrs'
#        if not os.path.exists(oldPRsDir):
#                os.mkdir(oldPRsDir)
#                
#        print("\nMove old PRs (>30 days) into " + oldPRsDir +" directory.")
#        #  find . -maxdepth 1 -type d -ctime +30 ! -name HPCC-Platform ! -name OldPrs -exec mv  '{}' OldPrs/. \;
#        # Move all directory which is older than 30 days, but not HPCC-Platform or OldPrs to OldPrs directory
#        myProc = subprocess.Popen(["find . -maxdepth 1 -type d -mtime +30 ! -name HPCC-Platform ! -name 'Old*' -print -exec mv '{}' "+ oldPRsDir +"/. \;"],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
#        (myStdout,  myStderr) = myProc.communicate()
#        result = myStdout+ myStderr
#        print("Result:"+result)

        oldLogsDir='OldLogs'
        if not os.path.exists(oldLogsDir):
            print("Create '" + oldLogsDir + "'\n")
            os.mkdir(oldLogsDir)

        print("\nMove old logs (>6 days) onto " + oldLogsDir +" directory.")
        myProc = subprocess.Popen(["find . -maxdepth 1 -type f -mtime +6 -name 'prp-*' -print -exec mv '{}' " + oldLogsDir +"/. \;"],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
        (myStdout,  myStderr) = myProc.communicate()
        result = "returncode:" + str(myProc.returncode) + ", stdout:'" + myStdout + "', stderr:'" + myStderr + "'."
        print("Result:"+result)

        myProc = subprocess.Popen(["find . -maxdepth 1 -type f -mtime +6 -name 'bokeh-*' -print -exec mv '{}' " + oldLogsDir +"/. \;"],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
        (myStdout,  myStderr) = myProc.communicate()
        result = "returncode:" + str(myProc.returncode) + ", stdout:'" + myStdout + "', stderr:'" + myStderr + "'."
        print("Result:"+result)

        
        if removeMasterAtExit:
            print("\nRemove HPCC-Platform (master) to force clone it at the next start.")
            myProc = subprocess.Popen(["sudo rm -rf HPCC-Platform"],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            (myStdout,  myStderr) = myProc.communicate()
            result = "returncode:" + str(myProc.returncode) + ", stdout:'" + myStdout + "', stderr:'" + myStderr + "'."
            print("Result:"+result)
            
    except:
        print("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
    finally:
       print("Done, exit.")
    pass

def checkStop():
    global stopSmoketest
    global stopWait
    d =  os.getcwd()
    if os.path.exists('smoketest.stop'):
        stopSmoketest=True
        os.unlink('smoketest.stop')
        
    if os.path.exists('smoketest.recheck'):
        stopWait=True
        os.unlink('smoketest.recheck')

#
#----------------------------------------------------------------
# Self test
#

def doTest():
    testMode = 6
    
    curDir =  os.getcwd()
    # cd smoketest-<PRID>
    testDir = 'PR-' + testPrNo
    os.chdir(testDir)
    if testMode == 1:
        testRes = CollectResults('/home/ati/smoketest/PR-' + testPrNo + '/HPCCSystems-regression/log', [], testPrNo, True)
    elif testMode == 2:
        testRes = collectECLWatchBuildErrors()
    elif testMode == 3:
        #unicodestring = '\xa0'
        result = u'Build: failed \xc2\xae\n'
        result += "Error(s): 7\n"
        result += u"/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:595:27: error: expected initializer before ‘-’ token\n"
        result += u"/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:596:13: error: ‘fileSize’ was not declared in this scope\n"
        result += u"/mnt/disk1/home/vamosax/smoketest/smoketest-8652/HPCC-Platform/roxie/ccd/ccdfile.cpp:606:5: error: control reaches end of non-void function [-Werror=return-type]\n"
        result += "cc1plus: some warnings being treated as errors\n"
        result += "make[2]: *** [roxie/ccd/CMakeFiles/ccd.dir/ccdfile.cpp.o] Error 1\n"
        result += "make[1]: *** [roxie/ccd/CMakeFiles/ccd.dir/all] Error 2\n"
        result += "make: *** [all] Error 2\n"
        
        """
        result = "Build: failed \xc2\xae\n"
        result += "Error(s): 2\n"
        result += "CMake Error at cmake_modules/commonSetup.cmake:876 (message):\n"
        result += "-- Configuring incomplete, errors occurred!\n"
        """
        
        result = "Build: failed \xc2\xae\n"
        result += "../../Release/libs/libccd.so: undefined reference to `RowFilter::extractFilter(unsigned int)'\n"
        result += "../../Release/libs/libccd.so: undefined reference to `RowFilter::addFilter(IFieldFilter const&)'\n"
        result += "../../Release/libs/libccd.so: undefined reference to `RowFilter::recalcFieldsRequired()'\n"
        result += "../../Release/libs/libccd.so: undefined reference to `RowCursor::setRowForward(unsigned char const*)'\n"
        result += "../../Release/libs/libccd.so: undefined reference to `RowFilter::extractKeyFilter(RtlRecord const&, IConstArrayOf<IFieldFilter>&) const'\n"
        result += "../../Release/libs/libccd.so: undefined reference to `RowFilter::findFilter(unsigned int) const'\n"
        result += "../../Release/libs/libccd.so: undefined reference to `RowFilter::matches(RtlRow const&) const'\n"
        result += "Error(s): 7"
        
        msg= u'Automated Smoketest \n  \xe2\x80\x98 Test \xe2\x80\x99 \n'
            
        testRes = processResult(result,  msg, '')
        
    elif testMode == 4:
        result = "\n"
        result += "npm test\n"
        result += "res:\n"
        result += "> eclwatch@1.0.0 test /mnt/disk1/home/vamosax/smoketest/PR-12233/HPCC-Platform/esp/src\n"
        result += "> run-s lint\n"
        result += "> eclwatch@1.0.0 lint /mnt/disk1/home/vamosax/smoketest/PR-12233/HPCC-Platform/esp/src\n"
        result += "> jshint --config ./.jshintrc ./eclwatch\n"
        result += "eclwatch/XrefDetailsWidget.js: line 121, col 18, Unnecessary semicolon.\n"
        result += "1 error\n"
        result += " npm ERR! code ELIFECYCLE\n"
        result += "npm ERR! errno 2\n"
        result += "npm ERR! eclwatch@1.0.0 lint: `jshint --config ./.jshintrc ./eclwatch`\n"
        result += "npm ERR! Exit status 2\n"
        result += "npm ERR! \n"
        result += "npm ERR! Failed at the eclwatch@1.0.0 lint script.\n"
        result += "npm ERR! This is probably not a problem with npm. There is likely additional logging output above.\n"
        result += "npm WARN Local package.json exists, but node_modules missing, did you mean to install?\n"
        result += "npm ERR! A complete log of this run can be found in:\n"
        result += "npm ERR!     /mnt/disk1/home/vamosax/.npm/_logs/2019-02-27T16_48_09_789Z-debug.log\n"
        result += 'ERROR: "lint" exited with 2.\n'
        result += "npm ERR! Test failed.  See above for more details.\n"
        result += "npm test end\n"
        result += "Install HPCC Platform\n"

        
        msg= u'Automated Smoketest \n  \xe2\x80\x98 Test \xe2\x80\x99 \n'
        
            
        testRes = processResult(result,  msg, '')

    elif testMode == 5:
        result = "\n"
        result += "npm install start.\n"
        result += "Install ECLWatch build dependencies.\n"
        result += "sudo npm install -g jshint@2.9.4\n"
        result += "res:/usr/bin/jshint -> /usr/lib/node_modules/jshint/bin/jshint\n"
        result += "+ jshint@2.9.4\N"
        result += "updated 1 package in 2.979s\n"
        result += "npm install end.\n"
        result += "npm test\n"
        result += "res:\n"
        result += "> eclwatch@1.0.0 test /mnt/disk1/home/vamosax/smoketest/PR-12233/HPCC-Platform/esp/src\n"
        result += "> run-s lint\n"
        result += "> eclwatch@1.0.0 lint /mnt/disk1/home/vamosax/smoketest/PR-12233/HPCC-Platform/esp/src\n"
        result += "> jshint --config ./.jshintrc ./eclwatch\n"
        result += "npm test end\n"
        result += "Makefiles created (2019-02-28_09-07-19 45 sec )\N"
        result += "Build it\n"
        result += "Install HPCC Platform\n"

        msg= u'Automated Smoketest \n  \xe2\x80\x98 Test \xe2\x80\x99 \n'
            
        testRes = processResult(result,  msg, '')
        
    elif testMode == 6:
        buildLogFile = 'failedResult-20-02-18-12-45-59.log'
        pages = open(buildLogFile,  "r").readlines()
        result = ''.join(pages)
        result = result.replace('\t','')
        msg= u'Automated Smoketest \n  \xe2\x80\x98 Test \xe2\x80\x99 \n'
            
        # processResult(result,  msg,  resultFile,  buildFailed=False,  testFailed=False,  testfiles=None,
        testRes = processResult(result,  msg, '',   buildFailed=False,  testFailed=True,  testfiles='*.ecl')
        
        
    print('Result:')
    print(testRes)
    print('End.')
    os.chdir(curDir)
    return    
#
#----------------------------------------------------------------
# Main
#

if __name__ == '__main__':
    
    if testmode:
        print("testmode                                           : " + str(testmode))
        print("-----------------------------------------------------------------------")
 
        doTest()
        cleanUp('/home/ati/smoketest')
        exit()
        
    print("Start this day at "+ time.asctime())
    print("Runtime paramters:")
    print("------------------")
    print("Operating system is                                : " + sysId)
    print("Parent Command is                                  : " + parentCommand)
    print("Enable to remove HPCC-Platform directory at exit is: " + str(removeMasterAtExit))
    print("Enable shallow clone is                            : " + str(enableShallowClone))
    print("Add git comment is                                 : " + str(addGitComment))
    print("Run once is                                        : " + str(runOnce))
    print("Keep files is                                      : " + str(keepFiles))
    print("Test only one PR and exit is                       : " + str(testOnlyOnePR))
    print("Run full regression test is                        : " + str(runFullRegression))
    print("Use quick build is                                 : " + str(useQuickBuild))
    print("Build ECLWatch is                                  : " + str(buildEclWatch))
    print("Skip draft PR is                                   : " + str(skipDraftPr))
    print("Average Session Time                               : " + str(averageSessionTime)) + " hours"
    
    if testPrNo > 0:
        print("Test PR-" + str(testPrNo) + " only (if it is open) and exit.")

    print("\n")
    
    print("Register signal handler for SIGALRM, SIGTERM, SIGINT")
    signal.signal(signal.SIGALRM, handler)
    signal.signal(signal.SIGTERM, handler)
    signal.signal(signal.SIGINT, handler)

    atexit.register(on_exit)
    isClangTidy = checkClangTidy()
    if isClangTidy:
        print("The clang-tidy is installed and use to check c* code.")
    else:
        print("The clang-tidy is not istalled.")

    #Change to smoketest
    cwd = os.getcwd()
    home = '/home/ati/'
    if 'HOME' in os.environ:
        home =  os.environ['HOME']+'/'
    smoketestHome = home+'smoketest'
    if not os.path.exists(smoketestHome):
            os.mkdir(smoketestHome)
    os.chdir(smoketestHome)

    # Read GitHub access token
    if os.path.exists('token.dat'):
        file = open('token.dat', "r") 
        line = file.readline()
        gitHubToken = line.strip().replace('\n','')[0:40]
        file.close()
        print("GitHub token loaded.")
    else:
        gitHubToken = ''
        print("\nWARNING:\n--------\nThe GitHub access token file not found!")
        print("The Pull Request processing unable to access GitHub without token.\nnExit.")
        exit()
        
    idleTime = 60

    while True:
        startScriptTimestamp = time.time()
        print("Start: "+time.asctime())
        os.chdir(smoketestHome)
        #smoketestHome = os.getcwd()
        #knownPullRequests = glob.glob("smoketest-*") + glob.glob("PR-*")
        knownPullRequests = glob.glob("PR-*")
        (prs, numOfPrToTest, prSkipped) = GetOpenPulls(knownPullRequests)

        #print prs
        CleanUpClosedPulls(knownPullRequests,  smoketestHome)

#        CatchUpMaster()
#        print("[%s] - Check and remove all finished tasks from the list." % (threading.current_thread().name,  len(threads)))
#        for key in threads:
#            if not threads[key]['thread'].is_alive():
#                print("--- Finished key:%s, remove"  % (key))
#                del threads[key]
#        
        if prSkipped:
            HandleSkippedPulls(prSkipped)
            pass
        else:
            print("There is not skipped PR\n")
            
        if prs:
            try:
                # TODO Should check if there is enough time to finish all tests today.
                # If not then 
                #   a. Decrease the number of PRs to fit
                #   b. Postpone all to tomorrow
#                ProcessOpenPulls(prs,  numOfPrToTest)
                ScheduleOpenPulls(prs,  numOfPrToTest)
                pass
            except:
                print("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
                print "Exception in user code:"
                print '-'*60
                traceback.print_exc(file=sys.stdout)
                print '-'*60
                # To ensure we will go back to the Smokatest directory
                os.chdir(smoketestHome)
        else:
            print("Tere is not PR to process.\n")
            
        endScriptTimestamp = time.time()
        print("End:"+time.asctime())
        ellaps = endScriptTimestamp-startScriptTimestamp
        print("Total time:"+str(ellaps)+" sec.")
        
        if ellaps > 120:
            # There was at least one PR don't wait to much to next check
            idleTime = 0;
        else:
            # There wasn't any PR we can increase the idleTime
            if idleTime < maxIdleTime - 60:
                idleTime += 60


        t = time.localtime()
        if (t[3] == 23) and (t[4] > 30):
            print("Finish this day at "+ time.asctime())
            break
        else:
            if runOnce:
                print("It was an one-off attempt, exit.\n")
                break
        
            checkStop()
            if stopSmoketest:
                break
                
            if ellaps < idleTime:
                waitFor = idleTime - int(ellaps)
                print("Wait for a while ("+str(waitFor)+" sec)")
                while waitFor > 0:
                    if waitFor > 60:
                        time.sleep(60)
                        waitFor -= 60
                    else:
                        time.sleep(waitFor)
                        waitFor = 0
                    
                    checkStop()
                    if stopSmoketest or stopWait:
                        stopWait = False
                        break

                    print('\r {0:d} sec left'.format( waitFor))
                
            if stopSmoketest:
                break
                        
        pass
    
    # 
    
    print("[%s] - Wait for all (%d) tasks finish..." % (threading.current_thread().name,  len(threads)))
    stillActive = True
    while stillActive:
        print("Check at " + time.strftime("%Y.%m.%d %H:%M:%S"))
        stillActive = False
        for key in sorted(threads):
            if threads[key]['thread'].is_alive():
                elaps = time.time()-threads[key]['startTimestamp']
                print("--- PR-%s (%s) is scheduled and active. (started at: %s, elaps: %6d sec, %4d min))"  % (key, threads[key]['commitId'], threads[key]['startTime'], elaps,  elaps / 60 ) ) 
                stillActive = True
            else:
                print("--- PR-%s (%s) is finished" % (key,  threads[key]['commitId']))    
#        print("---------------------------------------------")
        
        if stillActive:
            time.sleep(120)
        
    print("All tasks are done")
        
    if stopSmoketest:
        print("\nExternal stop request received, exit.\n")    
    
    print("Finish at "+ time.asctime())
    
    cleanUp(smoketestHome)
    
