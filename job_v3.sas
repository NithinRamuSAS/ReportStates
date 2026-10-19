%let token=%sysget(SAS_CLIENT_TOKEN);
%let host=%sysfunc(getoption(SERVICESBASEURL));
%let state_content_location = /workshop/Courses/userdata/reportstates;

/*
 * The Studio compute context opens a default ODS HTML5 destination
 * pointing at _webout. Close it so proc json's output to _webout is
 * the only content returned to SAS Job Execution.
 */
ods _all_ close;

proc python;
submit;
SAS.hideLOG(False)
import os
import requests

token = SAS.symget('token')
host = SAS.symget('host')
reportID = SAS.symget('reportID')
request = SAS.symget('request')
state_content_location = SAS.symget('state_content_location')
print(request)

def retrieve_report_metadata(reportID):
    reportURI = 'reports/reports/' + reportID
    url = str(host) + '/' + reportURI
    headers = {"Authorization": "Bearer " + token,
            "Accept" : "application/json"}

    response = requests.get(url, headers=headers)
    print("retrieve_report_metadata executed with code: " + str(response.status_code))
    reportETag = response.headers['ETag']
    report_modified = response.json()['modifiedTimeStamp']
    return reportETag, report_modified

def delete_state(state_label):
    # delete state_label.txt from state_content_location:
    file_path = os.path.join(state_content_location, state_label + ".txt")
    if os.path.exists(file_path):
        try:
            os.remove(file_path)
            print("delete_state executed for state_label: " + state_label)
        except Exception as e:
            print("delete_state failed for state_label: " + state_label + " with error: " + str(e))

def retrieve_state_ETag(stateID):
    url = str(host) + "/reports/reports/" + reportID + "/states/" + stateID
    headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + token,
        "Accept": "application/json, application/vnd.sas.collection+json, application/vnd.sas.error+json"}

    response = requests.get(url, headers=headers)
    print("retrieve_state_ETag executed with code: " + str(response.status_code))
    stateETag = response.headers['ETag']
    return stateETag

def retrieve_states():
    # Return as table
    SAS.submit('''filename dir "&state_content_location.";

    data work.states;
    length label extension $256;
    did = dopen("dir");

    if did > 0 then do i = 1 to dnum(did);
    label = dread(did, i);
    extension = scan(label, -1, ".");
    if extension = "txt" then do;
    label = substr(label, 1, length(label) - 4);
    output;
    end;
    end;
    drop extension;
    rc = dclose(did);

    keep label;
    run;

    filename dir clear;''')

def retrieve_primary_state():
    url = str(host) + "/reports/reports/" + reportID + "/states"
    headers = {
    "Accept-Language": "",
    "Authorization": "Bearer " + token,
    "Accept": "application/json, application/vnd.sas.collection+json, application/vnd.sas.error+json"
    }
    response = requests.get(url, headers=headers)
    print("retrieve_primary_state executed with code: ", str(response.status_code))
    primaryStateID = next((state['id'] for state in response.json()['items'] if state['primary'] == True), None)
    return primaryStateID

def create_state(state_label, report_modified, primary=False):
    url = str(host) + "/reports/reports/" + reportID + "/states"

    if primary:
        payload = {
        "label": state_label,
        "reportModifiedTimeStamp": report_modified,
        "primary":True
    }
    else:
        payload = {
        "label": state_label,
        "reportModifiedTimeStamp": report_modified
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + token,
        "Accept": "application/json, application/vnd.sas.report.state.info+json, application/vnd.sas.error+json"
    }
    response = requests.post(url, json=payload, headers=headers)
    print("create_state executed with code: " + str(response.status_code))
    return response

def get_state_content(state_label):
    #read state_content from state_label.txt in state_content_location:
    with open(os.path.join(state_content_location, state_label + ".txt"), "r") as f:
        state_content = f.read()
    return state_content

def get_primary_state_content():
    stateID = retrieve_primary_state()
    url = str(host) + "/reports/reports/" + reportID + "/states/" + stateID + "/content"

    headers = {
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.sas.report.content+json, application/vnd.sas.error+json"}
        #"Accept": "application/vnd.sas.report.content+json, application/vnd.sas.report.content+xml, application/vnd.sas.error+json"}

    response = requests.get(url, headers=headers)
    print("get_primary_state_content executed with code: " + str(response.status_code))
    state_content = response.text
    return state_content

def put_state_content(stateID, stateETag, stateContent):
    url = str(host) + "/reports/reports/" + reportID + "/states/" + stateID + "/content"

    headers = {"If-Match" : stateETag,
            "Authorization": "Bearer " + token,
            "Content-Type": "application/vnd.sas.report.content+json",
            "Accept" : "application/vnd.sas.error+json"}

    response = requests.put(url, headers=headers, data=stateContent)
    print("put_state_content executed with code: " + str(response.status_code))

if request == 'GET':
    retrieve_states()

    # Return as JSON in _webout
    SAS.submit('''proc json out=_webout pretty; export work.states / nosastags; run;''')

elif request == 'DELETE':
    state_label = SAS.symget('stateLabel')
    delete_state(state_label)

elif request in ("BOOKMARK", "SAVE"):
    new_state_label = SAS.symget('newStateLabel')
    state_content = get_primary_state_content()
    loc = os.path.join(state_content_location, new_state_label + ".txt")
    with open(loc, "w") as f:
        f.write(state_content)
        print("saved in: ", loc)

elif request == "APPLY":
    state_label = SAS.symget('stateLabel')
    stateContent = get_state_content(state_label)
    reportETag, report_modified = retrieve_report_metadata(reportID)
    primaryStateID = retrieve_primary_state()
    if primaryStateID == None:
        primaryStateID = create_state("Primary", report_modified, primary=True)
    primaryStateETag = retrieve_state_ETag(primaryStateID)

    # Put stateContent into primaryState
    put_state_content(primaryStateID, primaryStateETag, stateContent)
endsubmit;
run;