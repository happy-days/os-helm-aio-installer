
#!/usr/bin/env python
import requests
import json
import urllib


def getBuild(logURL):
    try:
       response = requests.get(logURL).json()
   #response=urllib.urlopen(logURL).read()
    except:
       print('Error calling')
    else:
       data = response
       parsedValue = data['lastSuccessfulBuild']['number']
       return parsedValue


def getCommit(commitURL):
    try:
       response = requests.get(commitURL).json()
   #response=urllib.urlopen(logURL).read()
    except:
       print('Error calling')
    else:
       data = response
       #print response
       parsedValue = data['buildsByBranchName']['refs/remotes/origin/master']['revision']['SHA1']
       return parsedValue



logURL = "http://spoc-jenkins01.spoc.linux/job/Kolla_CI/api/json?pretty=true"
latestBuild = str(getBuild(logURL))
commitURL = "http://spoc-jenkins01.spoc.linux/job/Kolla_CI/"+latestBuild+"/git/api/json?pretty=true"
commitID = getCommit(commitURL)
print commitID

