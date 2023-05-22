#!/usr/bin/python3

import os
import subprocess
import sys
import inspect
import time
import glob

class GistLogHandler(object):
    
    def __init__(self, token=None, resultFile=None,  verbose=True):
        self.resultFile = resultFile
        
        if token == None:
            raise ValueError('Un-initialised token parameter')
        else:
            self.token = token
            
        if self.resultFile == None:
            curTime = time.strftime("%y-%m-%d-%H-%M-%S")
            resultFileName= "gistloghandler-" + curTime + ".log"
            self.resultFile = open(resultFileName,  "w")
        self.distDir = 'gists'
        self.curDir =  os.getcwd()
        self.verbose = verbose
        self.gistsIdFileName = 'gistsItems.dat'
        pass

    def __del__(self):
        if self.resultFile != None:
            self.resultFile.flush()
            self.resultFile.close()

    def myPrint(self, Msg, *Args):
        format=''.join(['%s']*(len(Args)+1)) 
        if self.verbose:
            print(format % tuple([Msg]+list(map(str,Args))))
            
        self.resultFile.write(format % tuple([Msg]+list(map(str,Args))))
        self.resultFile.flush()
    
    def formatResult(self, proc):
        retcode = proc.wait()
        stdout = proc.stdout.read().decode('utf-8').rstrip('\n').replace('\n','\n\t\t')
        if len(stdout) == 0:
            stdout = 'None'
        stderr = proc.stderr.read().decode('utf-8') .rstrip('\n').replace('\n','\n\t\t')
        if len(stderr) == 0:
            stderr = 'None'
        result = "returncode: " + str(retcode) + "\n\t\tstdout: " + stdout + "\n\t\tstderr: " + stderr
        
        if len(result) == 0:
            result = "\t\tOK"
            
        return (result, {'returncode' : retcode, 'stdout':stdout, 'stderr': stderr }) 
        
    def execCmd(self, cmd):
        self.myPrint("\tcmd: "+cmd + "\n")
        result = 'n/a'
        try:
            myProc = subprocess.Popen(cmd,  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
            result = self.formatResult(myProc)
        except OSError as e:
            self.myPrint(str(e))
            self.myPrint("OSError:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
            result = ''
            pass
        except:
            self.myPrint("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
            result = ''
            pass
        finally:
            self.myPrint("\tResult:", result)
            pass
        pass
        
        return result
        
    def createGist(self,  prId, commitId=None):
        self.prId = str(prId)
        if commitId == None:
            if os.path.exists('sha.dat'):
                file = open('sha.dat', "r") 
                line = file.readline()
                self.commitId = line.strip().replace('\n','')[0:8]
                file.close()
        else:
            self.commitId = commitId[0:8]
            
        # Gist upload record format:
        #{ 
        #"description": "<filename>", 
        #"public": true, 
        #"files": { 
        #   "<filename>": { 
        #         "content": "<log_as_a_string>" 
        #   } 
        # } 
        #}
        filename = 'PR-' + self.prId
        content = 'PR-' + self.prId + '  (Sha: ' + self.commitId + ')\\n'
        msg = "\'{\n"
        msg += "\"description\": \"" + filename +"\",\n"
        msg += "\"public\": true,\n"
        msg += "\"files\": { \n"
        msg += "   \"README.md\": { \n"
        msg += "       \"content\": \"" + content + "\"\n"
        msg += "    }\n"
        msg += "  }\n"
        msg += "}\'"
        
        cmd = 'curl -H "Content-Type: application/json" -H "Authorization: token ' + self.token + '" --data ' + msg +' https://api.github.com/gists'
        result = self.execCmd(cmd)
            
        haveId = False
        haveRawUrl = False
        haveHtmlUrl = False
        self.id = ''
        self.rawUrl = ''
        self.htmlUrl = ''
        for line in result[0].split('\n'):
            if "id" in line and not haveId:
                self.id = line.replace('"',  '').replace(',','').split(":")[1].strip()
                haveId = True
                self.myPrint("\tid:"+self.id + "\n")
                
            if "raw_url" in line and not haveRawUrl:
                items = line.replace('"',  '').replace(',','').split(":")
                self.rawUrl = items[1].strip() + ':' +items[2].strip()
                haveRawUrl = True
                self.myPrint("\trawUrl:"+self.rawUrl + "\n")
                
            if "html_url" in line and not haveHtmlUrl:
                items = line.replace('"',  '').replace(',','').split(":")
                self.htmlUrl = items[1].strip() + ':' +items[2].strip()
                haveHtmlUrl = True
                self.myPrint("\thtmlUrl:"+self.htmlUrl + "\n")
        pass
        
    def getGistUrl(self):
        self.myPrint("getGistUrl():"+self.htmlUrl + "\n")
        return self.htmlUrl
        
    def cloneGist(self):
        # git clone https://gist.github.com/<dist_id>.git ./gists
        #cmd = 'git clone https://gist.github.com/'+ self.id +'.git ' + self.distDir
        #cmd = 'git clone git@gist.github.com:'+ self.id +'.git ' + self.distDir
        cmd = 'git clone https://' + self.token + '@gist.github.com/'+ self.id +'.git ' + self.distDir
        tryCount = 5
        while (True):
            result = self.execCmd(cmd)

            if result[1]['returncode'] != 0:
                tryCount -=1
                if tryCount > 0:
                    self.myPrint("\tCommand failed, try again (%d attempts left).\n" % (tryCount))
                    #If gists dir exist then remove it to prevent 'git clone' command fails in next attempt 
                    if os.path.exists(self.distDir):
                        rmCmd = 'rm -rf ' + self.distDir
                        result2 = self.execCmd(rmCmd)
                   
                    continue
                else:
                    raise Exception('Can\'t clone git@gist.github.com: ' + self.id + '.git ' )
            else:
                break
                
            pass
        
        os.chdir(self.distDir)
        
        # Set origin to push

        cmd = 'git remote set-url origin https://' + self.token + '@gist.github.com/'+ self.id
        result = self.execCmd(cmd)

        
        os.chdir(self.curDir)
        pass
   
    def gistAddFile(self, filename):
        self.myPrint("gistAddFile(filename: '"+ filename + "')\n")
        os.chdir(self.distDir)
        
        # git add <filename>
        cmd = 'git add "' + filename + '"'
        result = self.execCmd(cmd)
        
        os.chdir(self.curDir)
          
    def gistAddBuildError(self, buildLogfileName, log):
        self.myPrint("gistAddBuildError(buildLogfileName: '%s', log: '%s'\n" % (buildLogfileName, log))
        
        logFilePath = self.distDir + '/' + buildLogfileName
        
        # Store log string into gist/<testname>/<logFileName>
        if os.path.exists(logFilePath):
            os.unlink(logFilePath)
        file = open(logFilePath, "w") 
        file.write('\n'.join(log))
        file.close()
        
        # Add logfile to git
        self.gistAddFile(buildLogfileName)
        
        # Copy CMakeError-<time_stamp>.log and CMakeOutput-<timestamp>.log files from PR-<prid>/ if they are exist
        cMakeResultFilesPath = './'
        cMakeResultFileNames = glob.glob( cMakeResultFilesPath + 'CMake*.log')
        
        for cMakeResultFileName in cMakeResultFileNames:
            cMakeResultFileName = cMakeResultFileName.replace(cMakeResultFilesPath, '')
            # copy ./CMake* file to gists/.
            cmd = 'cp ' + cMakeResultFilesPath + cMakeResultFileName + ' "gists/' + cMakeResultFileName + '"'
            result = self.execCmd(cmd)
            
            # Add CMake result file to git
            self.gistAddFile(cMakeResultFileName)
        
        # Generate link to the log like this:
        # https://gist.github.com/HPCCSmoketest/610732a311dc384fc32afe91a661582b#file-bug12130-multipart-false-w20170530-174223-3-log
        #
        # https://gist.github.com/HPCCSmoketest/<self.id>#file-<converted_logFileName>
        # where the converted_logFileName is: remove all '(', ')', replace ' ', '.', '=' to '-'
        convertedLogFileName = buildLogfileName.lower().replace('(','').replace(')','').replace(' ','-').replace('.','-').replace('=','-')
        rawUrl = 'https://gist.github.com/HPCCSmoketest/' + self.id + '#file-' + convertedLogFileName
        linkTag = "[Build log](" + rawUrl + ")"
        id = self.id
        self.myPrint("id:%s\nraw Link:%s\n" % (id,  linkTag))
        
        return (linkTag, id)
        pass
    
    def gistAddTraceFile(self):
        # Copy '*.trace' files from PR-<prid>/ if they are exist
        isCoreFlesReported = False
        traceFilesPath = './'
        traceFileNames = glob.glob( traceFilesPath + '*.trace')
        print("Tracefilenames:", end=' ')
        print(traceFileNames)
        for traceFileName in traceFileNames:
            if not isCoreFlesReported:
                self.updateReadme( "Core trace files:")
                isCoreFlesReported = True
                
            traceFileName = traceFileName.replace(traceFilesPath, '')
            rawUrl = 'https://gist.github.com/HPCCSmoketest/' + self.id + '#file-' + traceFileName
            linkTag = "[" + traceFileName + "](" + rawUrl + ")"
            self.updateReadme('- ' + linkTag)
            # copy trace file to gists/.
            cmd = 'mv ' + traceFilesPath + traceFileName + ' "gists/' + traceFileName + '"'
            result = self.execCmd(cmd)
            print("\tresult:"+result[0] + "\n")
            
            # Add CMake result file to git
            self.gistAddFile(traceFileName)
            
        return isCoreFlesReported
    
    def gistAddError(self, testname, log, wuid):
        self.myPrint("gistAddError(testname: '%s', log: '%s', wuid: '%s' \n" % (testname, log, wuid))
        logFileName = testname + '-' + wuid + '.log'
        logFilePath = self.distDir + '/' + logFileName
        
        # Store log string into gist/<testname>/<logFileName>
        if os.path.exists(logFilePath):
            os.unlink(logFilePath)
        file = open(logFilePath, "w") 
        file.write('\n'.join(log))
        file.close()
        
        # Add logfile to git
        self.gistAddFile(logFileName)
        
        # Copy ZAPReport file from PR-<prid>/HPCCSystems-regression/zap/<zapfile> if it is exists
        # The ZAPReport file name format is: "ZAPReport_<WUID>_<USERNAME>.zip"
        zapFilePath = 'HPCCSystems-regression/zap/'
        zapFileNames = glob.glob( zapFilePath + 'ZAPReport_' + wuid + '_*.zip')
        
        if len(zapFileNames) > 0:
            zapFileName = zapFileNames[0].replace(zapFilePath, '')
            # copy /HPCCSystems-regression/zap/<zapfile> to gists/.
            cmd = 'cp ' + zapFilePath + zapFileName + ' "gists/' + testname + '-' + zapFileName + '"'
            result = self.execCmd(cmd)
            
            # Add zapfile to git
            self.gistAddFile(testname + '-' + zapFileName)
        
        # Generate link to the log like this:
        # https://gist.github.com/HPCCSmoketest/610732a311dc384fc32afe91a661582b#file-bug12130-multipart-false-w20170530-174223-3-log
        #
        # https://gist.github.com/HPCCSmoketest/<self.id>#file-<converted_logFileName>
        # where the converted_logFileName is: remove all '(', ')', replace ' ', '.', '=' to '-'
        convertedLogFileName = logFileName.lower().replace('(','').replace(')','').replace(' ','-').replace('.','-').replace('=','-')
        rawUrl = 'https://gist.github.com/HPCCSmoketest/' + self.id + '#file-' + convertedLogFileName
        linkTag = "[" + testname + "](" + rawUrl + ")"
        id = self.id
        self.myPrint("id:%s\nraw Link:%s\n" % (id,  linkTag))
        
        pass
        return (linkTag, id)
    
    def updateReadme(self,  msg):
        self.myPrint("updateReadme(msg: '%s'" % msg)
        # Originally it was 80, but now the test items contain links, 
        # it would be much longer
        maxLineLen = 4 * 80 
        readMeFilePath = self.distDir + '/README.md'
        file = open(readMeFilePath, "a") 
        file.write('\n')
        # Wrap the msg if it is too long in one line
        divisions = msg.strip().split('\n')
        for division in divisions:
            if ',' in division:
                # list of failed test cases
                division = division.replace('- ', '').strip()
                items = division.split(',')
                
                line = '    - '
                for item in items:
                    item = item.strip()
                    if len(item) == 0:
                        continue
                    if not item[0].isdigit() :
                        # Part of version info, add it to this line
                        line += item
                        continue
                    if len(line) > maxLineLen:
                        file.write(line +'\n')
                        line = '    - '
                    if line.endswith(')'):
                        line += ', '
                    line += item +', '
                    
                file.write(line +'\n')
            else:
                # some headers
                file.write(division +'\n')
                
        file.close()

    def commitAndPush(self):
        os.chdir(self.distDir)
        
        # git commit 
        cmd = 'git commit -a -s -m "Add logs and ZAPs"'
        result = self.execCmd(cmd)
        
        # git push 
        cmd = 'git push origin main'
        result = self.execCmd(cmd)
       
        os.chdir(self.curDir)
       
        

        gistFile = open(self.gistsIdFileName,  "a")
        gistFile.write(self.id + ', ' + self.rawUrl + '\n')
        gistFile.close()
        
        # Move gists directory into a zip archive
        curTime = time.strftime("%y-%m-%d-%H-%M-%S")
        gistsZipFileName = self.gistsIdFileName.replace('.dat','-' + curTime + '.zip')
        cmd = "zip " + gistsZipFileName + " -m -r gists"
        result = self.execCmd(cmd)

    def removeGists(self, removeAll = False):
        try:
            if os.path.exists(self.gistsIdFileName):
                file = open(self.gistsIdFileName, "r")
                gists = file.readlines()
                file.close()
                numOfGists = len(gists)
                newGistsIds = []
                if not removeAll:
                    # Keep last one
                    numOfGists -= 1
                    newGistsIds.append(gists[numOfGists])
                    
                for index in range(numOfGists):
                    (id,  link) = gists[index].replace('\n','').split(',')
                    self.resultFile.write("\tid: %s, link: %s\n" % (id,  link))
                    cmd = 'curl -H "Content-Type: application/json" -H "Authorization: token ' + self.token + '" --request DELETE https://api.github.com/gists/' + id
                    result = self.execCmd(cmd)
                        
                if not removeAll:
                    # Re-write gists ID file with the last one
                    file = open(self.gistsIdFileName, "w")
                    for index in range(len(newGistsIds)):
                        file.write(newGistsIds[index])
                    file.close()
                else:
                    # Remove gist ID file
                    os.unlink(self.gistsIdFileName)
                
        except:
            print("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
            pass
        finally:
            pass
            
        pass
#
#-----------------------------------------------------------------
#
# Main
#

if __name__ == '__main__':
    
	try:
		token = open("token.dat", "r")
    	
		gistHandler = GistLogHandler(token.readline().strip())
		gistHandler.removeGists(True)
		gistHandler.createGist(999, 'cafebabe')
		gistHandler.cloneGist()
		gistHandler.updateReadme('OS: blabla\n')
		gistHandler.updateReadme('More blabla \\n ' + time.strftime("%y-%m-%d-%H-%M-%S") + ' \\n ')
		gistHandler.commitAndPush()
	except Exception as e:
		print(str(e))

