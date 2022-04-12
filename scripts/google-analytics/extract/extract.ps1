<#

# Steps to create an account (easy access via api token)

1. Log into https://console.developers.google.com/
2. Authenticate with your Google Analytics account
3. Add an api token, restrict it to the `Analytics Reporting API` and "Google Analytics Data API` and note the api key
4. Create a project and add `Google Analytics Reporting API` and `Google Analytics Data API` libraries to the project


# Documentation
https://developers.google.com/analytics/devguides/reporting/core/v4/?hl=de
https://developers.google.com/analytics/devguides/reporting/core/v4/rest/?hl=de
https://developers.google.com/analytics/devguides/reporting/core/v4/samples?hl=de
https://developers.google.com/analytics/devguides/reporting/core/v4/limits-quotas

# Notes

For different APIs here is a good hint on https://developers.google.com/analytics/devguides/reporting/data/v1/property-id?hl=de

Note: If the Property Settings shows a "Tracking Id" such as "UA-123...-1", this Property is a *Universal Analytics* property,
and the Analytics data for that property cannot be reported on in the Data API. For that property, you can use the
Google Analytics Reporting API v4 to produce analytics data reports.

# Access

{
  "error": {
    "code": 401,
    "message": "API keys are not supported by this API. Expected OAuth2 access token or other authentication credentials that assert a principal. See https://cloud.google.com/docs/authentication",
    "status": "UNAUTHENTICATED",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.ErrorInfo",
        "reason": "CREDENTIALS_MISSING",
        "domain": "googleapis.com",
        "metadata": {
          "service": "analyticsreporting.googleapis.com",
          "method": "google.analytics.reporting.v4.Reporting.GetReports"
        }
      }
    ]
  }
}

#>

# https://lvngd.com/blog/access-the-google-analytics-reporting-api-with-python/
# https://developers.google.com/analytics/devguides/reporting/core/v4/quickstart/service-py

#-----------------------------------------------
# SET LOCATION 
#-----------------------------------------------

# TODO [ ] replace with scriptpath

Set-Location -path "C:\Users\Florian\Documents\GitHub\AptecoHelperScripts\scripts\google-analytics\extract"


#-----------------------------------------------
# LOAD FUNCTIONS
#-----------------------------------------------

# Load jwt functions
. ".\JWT.ps1"


#-----------------------------------------------
# SETTINGS
#-----------------------------------------------

<#
Note: Add email of service account like apt-api-access@iconic-subject-999999.iam.gserviceaccount.com to the users (view is good enough) with role "reader" (lowest role)
#>

# GA settings
$viewID = "99999999" # ID der Datenansicht

# Google dev settings
$keyfile = ".\iconic-subject-999999-2e608bfb4003.json" # json file, not usable here at the moment
$certfile = ".\iconic-subject-999999-e888b294c987.p12" # pfx/p12 file for downwards compatibility
$certfileSecret = "notasecret" # TODO [ ] encrypt this key and use securestring
$scope = "https://www.googleapis.com/auth/analytics.readonly"


#-----------------------------------------------
# CREATE JWT SIGNATURE
#-----------------------------------------------

# Load google dev keyfile
$j = Get-Content -Path $keyfile -Encoding utf8 -Raw | ConvertFrom-Json -Depth 99

$headers = [ordered]@{
  "alg"="RS256"    
  "typ"="JWT"
}

# TODO [ ] check to load these values from the cert rather than json
$payload = [ordered]@{
  "iss" = $j.client_email #"761326798069-r5mljlln1rd4lrbhg75efgigp36m78j5@developer.gserviceaccount.com"
  "scope" = $scope
  "aud" = $j.token_uri
  "exp" = ( Get-UnixTime ) + 600 # valid for ten minutes at the moment
  "iat" = Get-Unixtime
}

# https://docs.microsoft.com/de-de/dotnet/api/system.security.cryptography.x509certificates.x509certificate2.-ctor?view=net-6.0
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certfile,$certfileSecret)

# RSA SHA-256
$jwt = Encode-JWT -headers $headers -payload $payload -cert $cert -alg "RS256"


#-----------------------------------------------
# REQUEST ACCESS TOKEN
#-----------------------------------------------

# Request the token - valid for 10 minutes
$contentType = "application/x-www-form-urlencoded"
$body = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=$( $jwt )"
$token = Invoke-RestMethod -Method POST -Uri $j.token_uri -body $body -ContentType $contentType

# Now put this into headers
$headers = [Hashtable]@{
  "Authorization" = "Bearer $( $token.access_token )"
}


# Using a service account like in https://developers.google.com/analytics/devguides/reporting/core/v4/authorization
# Note: You need to add the service account email address as an authorized user of the view (profile) you want to access.
# https://developers.google.com/analytics/devguides/reporting/core/v4/quickstart/service-py


#-----------------------------------------------
# CREATE REPORT DEFINITION
#-----------------------------------------------

$bd = @"
{
  "reportRequests":[
  {
    "viewId":"$( $viewID )",
    "dateRanges":[
      {
        "startDate":"2021-09-01",
        "endDate":"2021-12-01"
      }],
    "metrics":[
      {
        "expression":"ga:sessions"
      }],
    "dimensions": [
      {
        "name":"ga:browser"
      }]
    }]
}
"@


#-----------------------------------------------
# GET REPORT DATA BACK FROM GOOGLE ANALYTICS REPORTING API
#-----------------------------------------------

# TODO [ ] check if token is still valid before every request

$d = Invoke-RestMethod -ContentType "application/json; charset=utf-8" -Method "POST" -Headers $headers -Uri "https://analyticsreporting.googleapis.com/v4/reports:batchGet" -Body $bd -Verbose

$d | ConvertTo-Json -Depth 99

EXIT 0

# https://developers.google.com/analytics/devguides/reporting/core/v4/rest/v4/reports/batchGet?apix_params=%7B%22resource%22%3A%7B%7D%7D#request-body
# https://ga-dev-tools.web.app/request-composer/

<#
"https://analyticsreporting.googleapis.com"

$key = "&key=AIzaSyDUwaOZgYV1acXDI1fwfAh6UOTqDsE4Ceg"
$ga4PropertyId = "UA-165573271-1"
$ga4Website = "217550773"

$headers = [Hashtable]@{
    #"Authorization" = "Bearer $( $key )"
}

# $body = [PSCustomObject]@{
#     Name = Value
# } | ConvertTo-Json -Depth 99 -Compress

$body = @"
{
    "dateRanges": [{ "startDate": "2020-09-01", "endDate": "2020-09-15" }],
    "dimensions": [{ "name": "country" }],
    "metrics": [{ "name": "activeUsers" }]
}
"@
  

Invoke-RestMethod -ContentType "application/json; charset=utf-8" -Method "POST" -Headers $headers -Uri "https://analyticsdata.googleapis.com/v1beta/properties/$( $ga4Website ):runReport$( $key )" -Body $body -Verbose
#>


exit 0


@"
{
  "reportRequests": [
      {
          "viewId": "217550773",
          "dateRanges": [
              {
                  "startDate": "7daysAgo",
                  "endDate": "yesterday"
              }
          ],
          "metrics": [
              {
                  "expression": "ga:users"
              }
          ],
          "dimensions": [
              {
                  "histogramBuckets": [
                      1,
                      10,
                      100,
                      200,
                      400
                  ],
                  "name": "ga:userType"
              },
              {
                  "histogramBuckets": [
                      1,
                      10,
                      100,
                      200,
                      400
                  ],
                  "name": "ga:segment"
              }
          ],
          "filtersExpression": "ga:browser=~^Chrome",
          "segments": [
              {
                  "segmentId": "gaid::-1"
              }
          ],
          "samplingLevel": "DEFAULT"
      }
  ]
}
"@
