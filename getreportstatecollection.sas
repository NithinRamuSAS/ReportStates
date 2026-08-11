%let token=%sysget(SAS_CLIENT_TOKEN);
%let host=%sysfunc(getoption(SERVICESBASEURL));

proc python;
submit;

import requests
import pandas as pd

token = SAS.symget('token')
host = SAS.symget('host')

reportId = 'cf4255cf-0e01-48b5-ae02-7164d9d0f157'

def retrieve_etag(reportId):
    reportURI = 'reports/reports/' + reportId
    url = str(host) + '/' + reportURI
    headers = {"Authorization": "Bearer " + token,
               "Accept" : "application/json"}

    response = requests.get(url, headers=headers)
    return response.headers['ETag']

headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer " + token,
    "Accept": "application/json, application/vnd.sas.collection+json, application/vnd.sas.error+json"
}

url = str(host) + "/reports/reports/" + reportId + "/states"

response = requests.get(url, headers=headers)
ids = [item['id'] for item in response.json()['items']]
labels = [item['label'] for item in response.json()['items']]
primaries = [item['primary'] for item in response.json()['items']]

# Create a SAS dataset from the states list
states_df = pd.DataFrame({'id': ids, 'label': labels, 'primary': primaries})
SAS.df2sd(states_df, 'work.states')

endsubmit;
run;

/* Output the states dataset as JSON to the web browser */
proc json out=_webout pretty;
    export work.states / nosastags;
run;