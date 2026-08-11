%let reportID = cf4255cf-0e01-48b5-ae02-7164d9d0f157;
%let newStateLabel = sort_sports_2001q3;
%let token=%sysget(SAS_CLIENT_TOKEN);
%let host=%sysfunc(getoption(SERVICESBASEURL));
%let reportStateLocation = /create-export/create/homes/Nithin.Ramu@sas.com/casuser/sort_sports_2001q3_xml_state_content.txt;

proc python;
submit;
import requests

host = SAS.symget('host')
token = SAS.symget('token')
reportId = SAS.symget('reportID')
reportStateLocation = SAS.symget('reportStateLocation')
newStateLabel = SAS.symget('newStateLabel')

# Get Report ETag and Modified Timestamp
url = "https://create.demo.sas.com/reports/reports/" + reportId

headers = {
    # "If-None-Match": "",
    # "If-Modified-Since": "",
    "Authorization": "Bearer " + token,
    "Accept": "application/json, application/vnd.sas.report+json, application/vnd.sas.error+json"
}
response = requests.get(url, headers=headers)
print("Get Report ETag executed with code: " + str(response.status_code))
reportETag = response.headers['ETag']
reportModified = response.json()['modifiedTimeStamp']

# Get current Primary State
url = str(host) + "/reports/reports/" + reportId + "/states"

headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer " + token,
    "Accept": "application/json, application/vnd.sas.collection+json, application/vnd.sas.error+json"
}

response = requests.get(url, headers=headers)
print("Get current primary state executed with code: " + str(response.status_code))
currentStateId = next((state['id'] for state in response.json()['items'] if state['primary'] == True), None)

# Get current State ETag
url = str(host) + "/reports/reports/" + reportId + "/states/" + currentStateId
headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer " + token,
    "Accept": "application/json, application/vnd.sas.collection+json, application/vnd.sas.error+json"
}

response = requests.get(url, headers=headers)
print("Get current state ETag executed with code: " + str(response.status_code))
currentStateETag = response.headers['ETag']
currentStateLabel = response.json()['label']

# Update report state to make it secondary
url = "https://create.demo.sas.com/reports/reports/" + reportId + "/states/" + currentStateId

payload = {
    "id": currentStateId,
    "label": currentStateLabel,
    "primary": False,
    "reportModifiedTimeStamp": reportModified
}

headers = {
    "If-Match" : currentStateETag,
    "Authorization": "Bearer " + token,
    "Content-Type": "application/json",
    "Accept" : "application/json, application/vnd.sas.report.state.info+json, application/vnd.sas.error+json"
}

response = requests.put(url, headers=headers, json=payload)
print("Update current report state to make it secondary executed with code: " + str(response.status_code))

# Create new State
url = "https://create.demo.sas.com/reports/reports/" + reportId + "/states"

payload = {
    "label": newStateLabel,
    "reportModifiedTimeStamp": reportModified
}
headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer " + token,
    "Accept": "application/json, application/vnd.sas.report.state.info+json, application/vnd.sas.error+json"
}
response = requests.post(url, json=payload, headers=headers)
print("Create State executed with code: " + str(response.status_code))
stateId = response.json()['id']

# Get new State ETag
# url = str(host) + "/reports/reports/" + reportId + "/states/" + stateId
url = "https://create.demo.sas.com/reports/reports/" + reportId + "/states/" + stateId
headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer " + token,
    "Accept": "application/json, application/vnd.sas.collection+json, application/vnd.sas.error+json"
}

response = requests.get(url, headers=headers)
print("Get State ETag executed with code: " + str(response.status_code))
stateETag = response.headers['ETag']

# Put State Content
# url = str(host) + "/reports/reports/" + reportId + "/states/" + stateId + "/content"
url = "https://create.demo.sas.com/reports/reports/" + reportId + "/states/" + stateId + "/content"


headers = {"If-Match" : stateETag,
        "Authorization": "Bearer " + token,
        "Content-Type": "application/vnd.sas.report.content+xml",
        "Accept" : "application/vnd.sas.error+json"}
with open(reportStateLocation, 'r') as f:
    payload = f.read()
response = requests.put(url, headers=headers, data=payload)
print("save_state_content executed with code: " + str(response.status_code))
newStateETag = response.headers['ETag']

# Update report state to make it primary
url = "https://create.demo.sas.com/reports/reports/" + reportId + "/states/" + stateId

payload = {
    "id": stateId,
    "label": newStateLabel,
    "primary": True,
    "reportModifiedTimeStamp": reportModified
}

headers = {
    "If-Match" : newStateETag,
    "Authorization": "Bearer " + token,
    "Content-Type": "application/json",
    "Accept" : "application/json, application/vnd.sas.report.state.info+json, application/vnd.sas.error+json"
}

response = requests.put(url, headers=headers, json=payload)
print("Update report state executed with code: " + str(response.status_code))

endsubmit;
run;