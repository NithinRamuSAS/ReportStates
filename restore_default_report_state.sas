%let reportID  = ; /* insert your reportID between equals and semicolon */
/* retrieve the authorization token */
%let token=%sysget(SAS_CLIENT_TOKEN);
/* retrieve the Viya base URL */
%let host=%sysfunc(getoption(SERVICESBASEURL));

proc python;
submit;

import requests
# convert SAS macro variables to Python variables
token = SAS.symget('token')
host = SAS.symget('host')
reportId = SAS.symget('reportID')

def retrieve_primary_state(reportId):
    headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + token,
        "Accept": "application/json, application/vnd.sas.collection+json, application/vnd.sas.error+json"
    }
    url = str(host) + "/reports/reports/" + reportId + "/states"
    response = requests.get(url, headers=headers)
    # parse the items array:
    for item in response.json()['items']:
        # if an item has True for the primary key, return its id
        if item['primary']:
            stateId = item['id']
    return stateId

def delete_primary_state(reportId):
    stateId = retrieve_primary_state(reportId)
    headers = {
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.sas.error+json"
    }
    url = str(host) + "/reports/reports/" + reportId + "/states/" + stateId
    response = requests.delete(url, headers=headers)
    print(response)

if __name__ == '__main__':
    primary_state_content = delete_primary_state(reportId)
endsubmit;
run;
