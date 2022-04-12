
<#
# Browser

https://www.umweltbundesamt.de/daten/luft/luftdaten/stationen/eJzrXpScv9B0UXHyQqNFKYmrjAyMjHQNTHQNjBaVZC4yNFmUl7pgUXHJgiUpiW5FUFljXSMzID8kH1l1cuKERblVbItyk5sW5ySWnHbwXBVYnXv67OKcvPTTDipXGhgYGBgBBS4p4g==


# Stationen

https://www.umweltbundesamt.de/api/air_data/v2/stations/json?use=measure&lang=de&date_from=2022-01-01&time_from=1&date_to=2022-12-31&time_to=24


# Daten

## JSON

Feinstaub
https://www.umweltbundesamt.de/api/air_data/v2/measures/json?component=1&scope=1&date_from=2022-04-02&time_from=12&date_to=2022-04-02&time_to=12

Kohlenmonoxid
https://www.umweltbundesamt.de/api/air_data/v2/measures/json?component=2&scope=4&date_from=2022-04-02&time_from=13&date_to=2022-04-02&time_to=13

Ozon
https://www.umweltbundesamt.de/api/air_data/v2/measures/json?component=3&scope=4&date_from=2022-04-02&time_from=13&date_to=2022-04-02&time_to=13

Schwefeldioxid
https://www.umweltbundesamt.de/api/air_data/v2/measures/json?component=4&scope=2&date_from=2022-04-02&time_from=13&date_to=2022-04-02&time_to=13

Stickstoffdioxid
https://www.umweltbundesamt.de/api/air_data/v2/measures/json?component=5&scope=2&date_from=2022-04-02&time_from=13&date_to=2022-04-02&time_to=13

## CSV

https://www.umweltbundesamt.de/api/air_data/v2/measures/csv?date_from=2022-01-01&time_from=12&date_to=2022-04-02&time_to=12&data%5B0%5D%5Bco%5D=1&data%5B0%5D%5Bsc%5D=1&lang=de

#>

#-----------------------------------------------
# LOAD STATIONS DATA
#-----------------------------------------------

$timestamp = [datetime]::Now

# Define the settings for this call
$apiRoot = "https://www.umweltbundesamt.de/api/air_data/v2/"
$format = "json" # json|csv
$language = "de"
$year = "2022"
$dateformat = "yyyy-MM-dd"
$dateFrom = [datetime]::parse("$( $year )-01-01").toString($dateformat) #[datetime]::Now.AddDays(-90).ToString("yyyy-MM-dd")
$dateTo = [datetime]::parse("$( $year )-12-31").toString($dateformat) 
$timeFrom = "1"
$timeTo = "24"

# prepare the api call
$restParam = [Hashtable]@{
    Uri = "$( $apiRoot )stations/$( $format )?use=measure&lang=$( $language )&date_from=$( $dateFrom )&time_from=$( $timeFrom )&date_to=$( $dateTo )&time_to=$( $timeTo )"
    Method = "Get"
    ContentType = "application/json;charset=utf-8"
    Verbose = $true
}

# call the API for gathering the data
$stations = Invoke-Restmethod @restParam

# Split out the attributes
$attributes = $stations.indices

# Transform the stations data into something more readable
$stationsData = [System.Collections.ArrayList]@()
$stations.data | Get-Member | where { $_.MemberType -eq "NoteProperty" } | ForEach {

    $station = $_.Name
    $stationData = $stations.data.$station

    $stationObj = [PSCustomObject]@{}
    For ( $i = 0; $i -lt $attributes.Count ; $i++ ) {
        $stationObj | Add-Member -MemberType NoteProperty -Name $attributes[$i] -Value $stationData[$i]
    }

    [void]$stationsData.Add( $stationObj )

}

$duration = New-TimeSpan -Start $timestamp -End ( [datetime]::Now )

"This took $( $duration.TotalSeconds ) seconds in total"

$stationsData | Out-GridView