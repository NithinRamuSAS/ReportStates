

* Get Ready;
%let token=%sysget(SAS_CLIENT_TOKEN);
%let host=%sysfunc(getoption(SERVICESBASEURL));
%let reportID = cf4255cf-0e01-48b5-ae02-7164d9d0f157;

proc python;
submit;

# Get ready
import requests
token = SAS.symget('token')
host = SAS.symget('host')
reportId = SAS.symget('reportID')

# Get reportModified
url = str(host) + '/reports/reports/' + reportId
headers = {"Authorization": "Bearer " + token,
           "Accept" : "application/json"}
response = requests.get(url, headers=headers)
print(response)
reportModified = response.json()['modifiedTimeStamp']

# Get all report states
headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer " + token,
    "Accept": "application/json, application/vnd.sas.collection+json, application/vnd.sas.error+json"
}
url = str(host) + "/reports/reports/" + reportId + "/states"
response = requests.get(url, headers=headers)
stateIds = [item['id'] for item in response.json()['items']]

# Delete all report states
for stateId in stateIds:
    print(stateId)
    headers = {"Authorization": "Bearer " + token, "Accept": "application/vnd.sas.error+json"}
    url = str(host) + "/reports/reports/" + reportId + "/states/" + stateId
    response = requests.delete(url, headers=headers)
    print(response)

endsubmit;
run;