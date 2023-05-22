##Comment Removals

Line 5: "#import system"

Line 200: "#if testFiles[0].startswith('testing/regress/ecl/'):"

Line 217-218: "#print "ch10:'"+str(ch10)+"', ch11:'"+str(ch11)+"'"
        	#print "ch20:'"+str(ch20)+"', ch21:'"+str(ch21)+"'""

Line 222: "#print(val)"

Line 231: "#print '\n\n'"

Line 303: "#testName = items[0]+'.'+items[2].strip()"

Line 308: "#logs[prefix][testName][target]"

Lines 320-321: "#items = testname.split('.')
          	#line = "%-*s " % (20,  items[1])"
          	
Line 441: "#logs[prefix][testName][target]"

Line 461: "#inError=False"

Line 500: "#for testname in sorted(logs[prefix],  key=str.lower) :"

Line 504: "#print("%3d:%s-%s-%s" % (executed,  prefix,  target, testname))"

Line 533: "#print("total:%3d, pass: %3d, fails:%3d\n-----------------------\n" % (executed,  passed,  failed))"

Lines 583-584: "#items = testname.split('.')
               	#line = "%-*s " % (20,  items[1])"
               	
Lines 636-637: "#print("\t%s" % (str(m.groups())))
		 #retVal[m.group(2)] = m.group(1)"
		 
Lines 679-680 & 692-693: "# Using wget (problems on Replacement MFA machines)"
"#myProc = subprocess.Popen(["wget -S " + headers + " -OpullRequests.json https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)"

Lines 716-718: "#myProc = subprocess.Popen(["wget -S " + headers + " -OpullRequests"+str(page)+".json https://api.github.com/repositories/2030681/pulls?page="+str(page)],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)"
                "# Using wget (problems on Replacement MFA machines)"
                "#myProc = subprocess.Popen(["wget -S " + headers + " -OpullRequests"+str(page)+".json https://api.github.com/repos/hpcc-systems/HPCC-Platform/pulls?page="+str(page)], shell=True, bufsize=8192, stdout=subprocess.PIPE, stderr=subprocess.PIPE)"
                
Line 732: "#pulls_data += pulls_data2"

Line 746: "#print("Result: " + str(result))"
                
Line 755: "#print(pulls)"

Line 795: "#prs[prid]['cmd'] = 'git fetch -ff upstream pull/'+str(prid)+'/head:'+repr(pr['head']['ref'])+'-smoketest'"

Line 799: "#prs[prid]['cmd'] = 'git pull -ff upstream pull/'+str(prid)+'/head:'+repr(pr['head']['ref'])+'-smoketest'"

Line 884: "# buildSuccess= False"

Lines 895-902: "# The result of this code block never used, remove 
	   # buildSummaryFile = open(buildSummaryFileName, 'r')
	   # buildSummary = buildSummaryFile.readlines()
	   # buildSummaryFile.close()
 	   # for line in buildSummary:
	   #    if "Build success" in line:
	   #       buildSuccess = True
	   #       break"
	   
Lines 940-944: "#print("Build PR-"+str(prid)+", label: "+prs[prid]['label']+' sheduled to testing ('+prs[prid]['reason']+')')
            # generates changed file list:
            # wget -O<PRID>.diff https://github.com/hpcc-systems/HPCC-Platform/pull/<PRID>.diff
            #myProc = subprocess.Popen(["wget --timeout=60 -O"+testDir+"/"+str(prid)+".diff https://github.com/hpcc-systems/HPCC-Platform/pull/"+str(prid)+".diff"],  shell=True,  bufsize=65536,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)"
            
Lines 1117-1121: "#if prs[prid]['isDocsChanged']: # and not
                os.path.exists(buildSummaryFileName):
                # buildSummaryFile = open(buildSummaryFileName,  "wb")
                # buildSummaryFile.write( "Only documentation changed! Don't build." )
                # buildSummaryFile.close()
                # print("In PR-"+str(prid)+", label: "+prs[prid]['label']+" only documentation changed! Don't sheduled to testing ")"
                
Line 1125: "#print("Build PR-"+str(prid)+", label: "+prs[prid]['label']+" scheduled to testing (reason:'"+prs[prid]['reason']+"', is DOCS changed:"+str(prs[prid]['isDocsChanged'])+")")"

Line 1158: "#return (prs, buildPr)"

Lines 1307-1310: "  # Smoketest has no right to push
		    # print("\tgit push origin master")
		    # myProc = subprocess.Popen(["git push origin master"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
		    # result = formatResult(myProc)
		    "
		
Lines 1326-1342: "#        myProc = subprocess.Popen(["ecl --version"],  		shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
		#        result = myProc.stdout.read() + myProc.stderr.read()
		#        #results = result.split('\n')
		#        print("\t"+result)

		#        # Get the latest Regression Test Engine
		#        print("\tGet the latest Regression Test Engine from the master branch")
		#        myProc = subprocess.Popen(["git checkout master"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
		#        formatResult(myProc)
		#        
		#        if not os.path.exists('../rte'):
		#            os.mkdir('../rte')
		#        
		#        myProc = subprocess.Popen(["cp -v testing/regress/ecl-test* ../rte/"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
		#        formatResult(myProc)
		#        myProc = subprocess.Popen(["cp -v -r testing/regress/hpcc ../rte/hpcc"],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
		#        formatResult(myProc)"
		
Lines 1354-1356: "#    err = Error("6002")
		  #    logging.error("%s. checkHpccStatus error:%s!" % (1,  err))
		  #    raise Error(err)"

Lines 1361 - 1363: "#    err = Error("6003")
    		    #    logging.error("%s. checkHpccStatus error:%s!" % (1,  err))
    		    #    raise Error(err)"	
    		    
Line 1377: "#tableItems=[]"

Line 1423: "#values ="|""

Line 1513: "#result = result.replace('\n', '\\n')+"\\n""

Lines 1642-1643: " #msg +=  '\n' + buildErrorStr + '\n'
                   #buildFailed=False"
                   
Line 1647: " # eclWatchBuild = False"

Line 1689: " #buildFailed =  True"

Lines 1838-1839: "# Suite Error
		  # print("\tSuite Error"+result)"
		  
Line 1886: "#msg += result.replace('stopped',  'stopped,').replace('[32m','').replace('[33m','').replace('[0m', '\\n').replace('[31m', '\\n').replace("\\", "").replace('\<','<').replace('/>','>').replace('\xc2\xae','').replace('/*', '*').replace('*/', '*')" 

Line 1891: "#print(", "+result)"

Line 1906: "#eclWatchBuildError += result + '\n'"

Line 1931: " #eclWatchBuild=True"

Lines 1936-1940: "# msg += eclWatchTable.getTable()
		  # msg += '\n'
		  # if len(npmTestResultErr) > 0:
		  # 	print(npmTestResultErr)
		  #     msg += npmTestResultErr + '\n'"

Lines 1948-1950: "# items = result.split()
		  # eclWatchTable.addItem("lint " + items[1]+':'+items[0])
		  # #npmTestResult += 'Error(s): \n'"

Line 1979: "#msg = unicodedata.normalize('NFKD', msg).encode('ascii','ignore').replace('\'','').replace('\\u', '\\\\u')"

Lines 1987-1989: "# That was a vertical table, I think it is too big.
                  #timeStatsTable.addItem('Stage:' + items[0].replace(' time', '').strip() )
                  #timeStatsTable.addItem('Time: ' + items[1], ': ')"   
                  
Lines 1997-1999: "#        if len(msg) > maxMsgLen:
		  #            # Too much messsages something really wrong
		  #            break"
		  
Line 2034: "#.replace('\\xc2\\xae', '\xc2\xae')" 
**Note**: This is commented out of the end of "msg = msg.replace('[32m','').replace('[33m','').replace('[0m', '\\n').replace('[31m', '\\n').replace('\<','').replace('/>','').replace('\n', '\\n').replace('"', '\'')"

Line 2059: "#curDir =  os.getcwd()"
 
Line 2106: "#testDir = "smoketest-"+str(prid)"

Lines 2154-2158: "#resultFile.write("\tAdd comment to pull request\n\tComment Cmd:\n")
		#            resultFile.write("------------------------------------------------------\n")
		#            resultFile.write(addCommentCmd+"\n")
		#            resultFile.write("------------------------------------------------------\n")
		#            if addGitComment:"

Line 2181, 2192, 2200, 2208, 2291, 2327: "#resultFile.write("\tresult:"+result+"\n")"

Line 2310: "#result = formatResult(myProc, resultFile,  noEcho)"

Lines 2341-2342: " #resultFile.write("\tscl enable devtoolset-2 "+os.getcwd()+"/build.sh " + prs[prid]['regSuiteTests'] + "\n")
                   #myProc = subprocess.Popen(["scl enable devtoolset-2 "+os.getcwd()+"/build.sh " + prs[prid]['regSuiteTests'] ],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.PIPE)"
                   
Line 2360: "#myProc = subprocess.Popen(["./build.sh " + prs[prid]['regSuiteTests']  ],  shell=True,  bufsize=8192,  stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.PIPE)"

Lines 2365-2366: "#myStdout = myProc.stdout.read()
                #myStderr = myProc.stderr.read()"
     
Line 2386: "#print("\t"+result)"

Lines 2405-2406: " #while ( msg[maxMsgLen-1] == '\\' ):
                     #    maxMsgLen -= 1
                     
Line 2428: "#msg = msg.replace('stopped',  'stopped,').replace("\\", "").replace('[32m','').replace('[33m','').replace('[0m', '\\n').replace('[31m', '\\n').replace('\<','').replace('/>','').replace('\xc2\xae','')"

Lines 2433-2436: "#resultFile.write("\tAdd comment to pull request\n\tComment Cmd:\n")
				#            resultFile.write("------------------------------------------------------\n")
				#            resultFile.write(addCommentCmd+"\n")
				#            resultFile.write("------------------------------------------------------\n")"
				
Lines 2437-2441: "#            if addGitComment:
			    uploadGitHubComment(addCommentCmd,  resultFile)
		#            else:
		#                msgId = MessageId(resultFile)
		#                msgId.addNewFromResult(result)"
**Note:** "uploadGitHubComment(addCommentCmd,  resultFile)" is not commented.

Lines 2517-2518: "#if not isBuild and os.path.exists(resultFileName):
		  #os.unlink(resultFileName)"
		  
Lines 2654-2656: "#result = myProc.stdout.read() + myProc.stderr.read()
		  #print("\t"+result)
		  #resultFile.write("\tresult:"+result+"\n")"
		  
Lines 2730-2740: "#        oldPRsDir='OldPrs'
		#        if not os.path.exists(oldPRsDir):
		#                os.mkdir(oldPRsDir)
		#                
		#        print("\nMove old PRs (>30 days) into " + oldPRsDir +" directory.")
		#        #  find . -maxdepth 1 -type d -ctime +30 ! -name HPCC-Platform ! -name OldPrs -exec mv  '{}' OldPrs/. \;
		#        # Move all directory which is older than 30 days, but not HPCC-Platform or OldPrs to OldPrs directory
		#        myProc = subprocess.Popen(["find . -maxdepth 1 -type d -mtime +30 ! -name HPCC-Platform ! -name 'Old*' -print -exec mv '{}' "+ oldPRsDir +"/. \;"],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
		#        (myStdout,  myStderr) = myProc.communicate()
		#        result = myStdout+ myStderr
		#        print("Result:"+result)"
		
Line 2895: "# processResult(result,  msg,  resultFile,  buildFailed=False,  testFailed=False,  testfiles=None,"

Line 2985-2986: "#smoketestHome = os.getcwd()
        	 #knownPullRequests = glob.glob("smoketest-*") + glob.glob("PR-*")"
        	 
