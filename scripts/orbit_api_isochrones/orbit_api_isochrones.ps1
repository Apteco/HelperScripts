
# https://docs.microsoft.com/en-us/bingmaps/rest-services/routes/calculate-an-isochrone

################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"

# Load settings
$settings = @{
    accessKey = "<accessKey>"
}


# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        ,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}


################################################
#
# FUNCTIONS
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}


################################################
#
# ENCRYPT IF NEEDED
#
################################################



if ( $settings.accessKey -eq "" ) {
    $accessTokenEncrypted = Get-PlaintextToSecure (Read-Host -AsSecureString "Please enter the key to encrypt")
    Write-Host "Please put this string into the settings at the accessKey"
    Write-Host $accessTokenEncrypted
    exit 0
}




################################################
#
# SETTINGS
#
################################################

# settings
#$bingKey = "AopPdMS1q3srfGOzETp7zwcX-qw4wXaGKYsWIBthadN27mHRDcGgMdg1mLEEJx6x" #( Get-SecureToPlaintext -String $settings.accessKey )
$bingKey = "<bingkey>"
$contentType = "application/json; charset=utf-8"

# geocode of point
$query = Read-Host "Which place do you want to search for?"
$queryEncoded = [uri]::EscapeDataString($query) #"k%C3%B6lner%20dom"
$url = "$( $apiBase )Locations?query=$( $queryEncoded )&key=$( $bingKey )"
$p = Invoke-RestMethod -Method Get -Uri $url -Verbose -ContentType $contentType

# choose the base coordinates
$point = $p.resourceSets.resources.geocodePoints | Out-GridView -PassThru
$pointLat = [math]::Round($point.coordinates[0],6) -replace ",","."
$pointLong = [math]::Round($point.coordinates[1],6) -replace ",","."

# create isochrone around point
$minutes = Read-Host "How many minutes?"
$travelMode = Read-Host "driving|walking|transit|truck?" # driving|walking|transit|truck
$url = "$( $apibase )Routes/Isochrones?waypoint=$( $pointLat ),$( $pointLong )&maxtime=$( $minutes )&timeUnit=minute&distanceUnit=km&travelMode=$( $travelMode )&key=$( $bingKey )"
$c = Invoke-RestMethod -Method Get -Uri $url -Verbose -ContentType $contentType

# The way with indexes so we can write a csv file
# Iterate through all coordinates
$polygonsArray = @()
$csv = @()
$polygons = $c.resourceSets.resources.polygons
for ($i = 0 ; $i -lt $polygons.count ; $i++) {
    $polygon = $polygons[$i]
    $coordinates = $polygon.coordinates[0]
    $coordinatesArray = @()
    for ($j = 0; $j -lt $coordinates.Count ; $j++) { # TODO [ ] think about leaving every second point out
        $coordinate = $coordinates[$j]
        $lat = [math]::Round($coordinate[0],6) -replace ",","." # latitude
        $long = [math]::Round($coordinate[1],6) -replace ",","." # longitude  
        $coordinatesArray += $lat
        $coordinatesArray += $long
        $csv += [PSCustomObject]@{
            polygon = $i
            coordinate = $j
            polycoordinate = "$($i)-$($j)"
            latitude = $lat
            longitude = $long
        }
    }
    $polygonsArray += ( $coordinatesArray -join "," )
}

# Build the expression for FastStats
$stringArray = @()
$polygonsArray | ForEach {
    $stringArray += "GeoPointInArea([Latitude],[Longitude],$( $_ ))"
}

# Export coordinates as csv (e.g. for QGIS) and the expression for FastStats
$csv | export-csv -path "C:\Users\Florian\Desktop\20201202\orbit_api_isochrones\coordinates.tsv" -Encoding UTF8 -NoTypeInformation -Delimiter "`t"
"Or($( $stringArray -join ", " ))" | Set-Content -Path "C:\Users\Florian\Desktop\20201202\orbit_api_isochrones\expression.txt"
exit 0

# TODO [ ] add example to directly count against OrbitAPI
# TODO [ ] Then export the result as csv
# TODO [ ] Also export the result as urn


<#
The way without indexes
$c.resourceSets.resources.polygons | ForEach {
    $polygon = $_
    $coordinatesArray = @()
    $polygon.coordinates[0] | ForEach {
        $coordinates = $_
        $coordinatesArray += [math]::Round($coordinates[0],6) -replace ",","." # latitude
        $coordinatesArray += [math]::Round($coordinates[1],6) -replace ",","." # longitude        
    }
    $polygonsArray += ( $coordinatesArray -join "," )
}
#>

#$polygonsArray