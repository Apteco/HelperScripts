# Load settings
#$settings = Get-Content -Path $settingsFilename -Encoding UTF8 -Raw | ConvertFrom-Json #"$( $scriptPath )\$( $settingsFilename )"

$settings = [PSCustomObject]@{

    # general settings
    base = "https://nominatim.openstreetmap.org"
    sqliteDB = ""
    connectionString = "Data Source=datasource;Initial Catalog=database;Trusted_Connection=True;" #\SQL-P-APTECO
    changeTLS = $true
    logfile = "D:\Apteco\Scripts\geocoding_osm\geocoding.log"

    # OSM specific
    resultsLanguage = "de"      # provide country code for the language of the results
    useragent = "AptecoCustomerXXX"
    millisecondsPerRequest = 1000

    # field mapping
    map = [PSCustomObject]@{
        street = "Strasse2"
        city = "Ort"
        postalcode = "PLZ"
        #countrycode = ""
    }

    # 

}