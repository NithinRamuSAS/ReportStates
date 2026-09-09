%let reportID = YOUR-REPORT-ID;
%let newStateLabel = YOUR-REPORT-LABEL;
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
newStateLabel = SAS.symget('newStateLabel')

def create_state(newStateLabel):
    url = str(host) + "/reports/reports/" + reportId + "/states"

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
    status_code = str(response.status_code)
    print("Create State executed with code: " + str(status_code))
    stateId = response.json()['id']
    return status_code, stateId

def get_state_etag(stateId):
    url = str(host) + "/reports/reports/" + reportId + "/states/" + stateId
    headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + token,
        "Accept": "application/json, application/vnd.sas.collection+json, application/vnd.sas.error+json"
    }

    response = requests.get(url, headers=headers)
    status_code = str(response.status_code)
    print("Get State ETag executed with code: " + str(status_code))
    stateETag = response.headers['ETag']
    return status_code, stateETag

def update_report_state(stateId, stateETag, stateLabel, primary):
    url = str(host) + "/reports/reports/" + reportId + "/states/" + stateId

    payload = {
        "id": stateId,
        "label": stateLabel,
        "primary": primary,
        "reportModifiedTimeStamp": reportModified
    }

    headers = {
        "If-Match" : stateETag,
        "Authorization": "Bearer " + token,
        "Content-Type": "application/json",
        "Accept" : "application/json, application/vnd.sas.report.state.info+json, application/vnd.sas.error+json"
    }

    response = requests.put(url, headers=headers, json=payload)
    status_code = str(response.status_code)
    print("Update current report state to make it primary={} executed with code: ".format(primary) + status_code)
    return str(status_code)

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
if currentStateId == None:
    rc, currentStateId = create_state("Primary")

# Get current State ETag
rc, currentStateETag = get_state_etag(currentStateId)

# Update report state to make it secondary
rc = update_report_state(currentStateId, currentStateETag, "Primary", False)

# Create new State
rc, newStateId = create_state(newStateLabel)

# Get new State ETag
rc, newStateETag = get_state_etag(newStateId)

# Put State Content
url = str(host) + "/reports/reports/" + reportId + "/states/" + newStateId + "/content"


headers = {"If-Match" : newStateETag,
        "Authorization": "Bearer " + token,
        "Content-Type": "application/vnd.sas.report.content+xml",
        "Accept" : "application/vnd.sas.error+json"}
with open(reportStateLocation, 'r') as f:
    payload = f.read()
response = requests.put(url, headers=headers, data=payload)
print("save_state_content executed with code: " + str(response.status_code))
newStateETag = response.headers['ETag']

# Update report state to make it primary
rc = update_report_state(newStateId, newStateETag, newStateLabel, True)

endsubmit;
run;