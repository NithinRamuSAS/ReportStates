%let reportID = YOUR-REPORT-ID;
%let token=%sysget(SAS_CLIENT_TOKEN);
%let host=%sysfunc(getoption(SERVICESBASEURL));
%let reportStateLocation = PATH-TO-STATE-FILE;

proc python;
submit;
import requests

host = SAS.symget('host')
token = SAS.symget('token')
reportId = SAS.symget('reportID')
reportStateLocation = SAS.symget('reportStateLocation')

# Get Report ETag and Modified Timestamp
url = str(host) + "/reports/reports/" + reportId

headers = {
    "Authorization": "Bearer " + token,
    "Accept": "application/json, application/vnd.sas.report+json, application/vnd.sas.error+json"
}
response = requests.get(url, headers=headers)
print("Get Report ETag executed with code: " + str(response.status_code))
reportETag = response.headers['ETag']
reportModified = response.json()['modifiedTimeStamp']

# Get Primary State
url = str(host) + "/reports/reports/" + reportId + "/states"

headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer " + token,
    "Accept": "application/json, application/vnd.sas.collection+json, application/vnd.sas.error+json"
}

response = requests.get(url, headers=headers)
print("Get states executed with code: " + str(response.status_code))
stateId = next((state['id'] for state in response.json()['items'] if state['primary'] == True), None)

# Get State ETag
url = str(host) + "/reports/reports/" + reportId + "/states/" + stateId
headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer " + token,
    "Accept": "application/json, application/vnd.sas.collection+json, application/vnd.sas.error+json"
}

response = requests.get(url, headers=headers)
print("Get State ETag executed with code: " + str(response.status_code))
stateETag = response.headers['ETag']

# Get State Content
url = str(host) + "/reports/reports/" + reportId + "/states/" + stateId + "/content"

headers = {
    "Authorization": "Bearer " + token,
    "Accept": "application/vnd.sas.report.content+xml, application/vnd.sas.error+json"
}
response = requests.get(url, headers=headers)
print("Get State Content executed with code: " + str(response.status_code))

with open(reportStateLocation, 'w') as f:
    f.write(response.text)

endsubmit;
run;