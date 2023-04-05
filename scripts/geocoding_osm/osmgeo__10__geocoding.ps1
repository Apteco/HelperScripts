################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
	    
    }
}


################################################
#
# NOTES
#
################################################

<#

The policy is written down here: https://operations.osmfoundation.org/policies/nominatim/

Current policies:


    limit your requests to a single thread
    limited to 1 machine only, no distributed scripts (including multiple Amazon EC2 instances or similar)
    Results must be cached on your side. Clients sending repeatedly the same query may be classified as faulty and blocked.

    
    No heavy uses (an absolute maximum of 1 request per second).
    Provide a valid HTTP Referer or User-Agent identifying the application (stock User-Agents as set by http libraries will not do).
    Clearly display attribution as suitable for your medium.
    Data is provided under the ODbL license which requires to share alike (although small extractions are likely to be covered by fair usage / fair dealing).


#>

################################################
#
# SCRIPT ROOT
#
################################################

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
} else {
    $scriptPath = "$( $params.scriptPath )" 
}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

$script:moduleName = "OSM_GEOCODING"


try {

    # Load general settings
    . ".\bin\general_settings.ps1"

    # Load settings
    . ".\bin\load_settings.ps1"

    # Load network settings
    . ".\bin\load_networksettings.ps1"

    # Define dependencies
    . ".\bin\dependencies.ps1"

    # Load and check dependencies, functions and more
    . ".\bin\load_functions.ps1"

    # Start logging
    . ".\bin\startup_logging.ps1"

    # Load preparation ($cred)
    . ".\bin\preparation.ps1"
    
} catch {

    Write-Log -message "Got exception during start phase" -severity ERROR 
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ERROR
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ERROR
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ERROR
    
    throw $_.exception  

    exit 1

}




################################################
#
# PROGRAM
#
################################################

#exit 0


$addresses = [System.Collections.ArrayList]@()
try {


    ################################################
    #
    # TRY
    #
    ################################################

    #-----------------------------------------------
    # OPEN DATABASE
    #-----------------------------------------------


    $mssqlConnection = [System.Data.SqlClient.SqlConnection]::new()
    $mssqlConnection.ConnectionString = $settings.connectionString
    $mssqlConnection.Open()


    #-----------------------------------------------
    # READ DATABASE
    #-----------------------------------------------

    # Read No of rows and calculate runtime
    # Check all rows that haven't been requested yet

    $query = Get-Content -Path ".\sql\new_records.sql" -Raw -Encoding UTF8
    $data = Query-SQLServer -connection $mssqlConnection -query $query

    $ts = New-TimeSpan -Seconds $data.count
    Write-Log -Message "Got $( $data.count ) records to work on" -Severity INFO
    Write-Log -Message "This will need about $( $ts.Days ) days, $( $ts.Hours ) hours and $( $ts.Minutes ) minutes" -Severity INFO
    
    $insertStatement = Get-Content -Path ".\sql\upsert_record.sql" -Raw -Encoding UTF8

    

    #-----------------------------------------------
    # CREATE FIELD MAPPING
    #-----------------------------------------------

    Write-Log "This is the mapping of fields (left is source, right the openstreetmaps):" -Severity VERBOSE
    $paramMap = Convert-PSObjectToHashtable -InputObject $settings.map
    $reverseMap = [hashtable]@{}
    $paramMap.Keys | ForEach {
        $key = $_
        Write-Log "    $( $paramMap[$key] ) => $( $key )" -Severity VERBOSE        
        $reverseMap.Add($paramMap[$key], $key)
    }


    #-----------------------------------------------
    # LOOP THROUGH DATA
    #-----------------------------------------------

    $maxMillisecondsPerRequest = $settings.millisecondsPerRequest
    Write-Log "Will create 1 request per $( $maxMillisecondsPerRequest ) milliseconds" -Severity VERBOSE

    $counter = 0
    $succeeded = 0
    $failed = 0

    $data | ForEach {
        
        $counter += 1

        $addr = $_

        # Create address parameter string like streetSchaumainkai%2087&city=Frankfurt&postalcode=60589&countrycodes=de
        $addrParams = [System.Collections.ArrayList]@()
        $paramMap.Keys | ForEach {
            $key = $_
            $value = $addr[$paramMap[$key]]
            [void]$addrParams.add("$( $key )=$( [uri]::EscapeDataString($value) )")
        }

        # Parameters for call
        $restParams = @{
            Uri = "$( $settings.base )/search?$( $addrParams -join "&" )&format=jsonv2&accept-language=$( $settings.resultsLanguage )&addressdetails=1&extratags=1"
            Method = "Get"
            UserAgent = $settings.useragent
            Verbose = $false
        }

        # Request to OSM
        $start = [datetime]::Now
        $t = Measure-Command {
            # TODO [ ] possibly implement proxy, if needed
            $res = Invoke-RestMethod @restParams
        }

        $pl = ConvertTo-Json -InputObject $res -Depth 99 -Compress

        If ( "" -eq $pl ) {

            # Empty result -> do something with it?
            $failed += 1

            # Save data
            $insertSqlReplacement = [Hashtable]@{
                "#ID#"=$addr.Id
                "#SUCCESS#"= 0
                "#SRCHASH#"= "CAST('$( $data[0].AddressHash )' AS VARBINARY(MAX))" #$data[0].AddressHash
                "#OSMHASH#"= @() #Get-StringHash $addressString -returnBytes -hashName "SHA256"
                "#PAYLOAD#"= "{}" #ConvertTo-Json -InputObject $res -Depth 99 -Compress
            }
            $insertSql = Replace-Tokens -InputString $insertStatement -Replacements $insertSqlReplacement
            #$customersSql | Set-Content ".\$( $rabatteSubfolder )\$( $evrGUID ).txt" -Encoding UTF8

            # insert new address
            $insertSqlResult = NonQueryScalar-SQLServer -connection $mssqlConnection -command "$( $insertSql )"


        } else {

            $succeeded += 1

            # Create hash of address data
            $address = $res.GetEnumerator().address
            $addressString = "$( $address.road ) $( $address.house_number ), $( $address.postcode ) $( $address.city )" #, $( $address.country )"
            $res | Add-Member -MemberType NoteProperty -Name "address_string" -Value $addressString

            # Add address object to array
            [void]$addresses.Add( $res )

            # Save data
            $insertSqlReplacement = [Hashtable]@{
                "#ID#"=$addr.Id
                "#SUCCESS#"= 1
                #"#SRCHASH#"= "CAST('{$( $addr.AddressHash -join ", " )}' AS VARBINARY(MAX))"
                #"#OSMHASH#"= "CAST('$( Get-StringHash $addressString -returnBytes -hashName "SHA256")' AS VARBINARY(MAX))" # Get-StringHash $addressString -returnBytes -hashName "SHA256"
                "#PAYLOAD#"= "'$( $pl )'"
            }
            $insertSql = Replace-Tokens -InputString $insertStatement -Replacements $insertSqlReplacement
            #$customersSql | Set-Content ".\$( $rabatteSubfolder )\$( $evrGUID ).txt" -Encoding UTF8

            $mssqlCommand = $mssqlConnection.CreateCommand()
            $mssqlCommand.CommandText = $insertSql
            $mssqlCommand.CommandTimeout = $settings.commandTimeout
            $mssqlCommand.Parameters.Add("@srcHash", [System.Data.SqlDbType]::VarBinary, 8000).Value = $addr.AddressHash
            $mssqlCommand.Parameters.Add("@osmHash", [System.Data.SqlDbType]::VarBinary, 8000).Value = [Byte[]](Get-StringHash $addressString -returnBytes -hashName "SHA256")
            $result = $mssqlCommand.ExecuteNonQuery()  #.ExecuteScalar()
            
            # insert new address
            #$insertSqlResult = NonQueryScalar-SQLServer -connection $mssqlConnection -command "$( $insertSql )"

        }
        $end = [datetime]::Now

        $ts = New-TimeSpan -Start $start -End $end

        # Wait until 1 second is full, then proceed
        If ( $ts.TotalMilliseconds -lt $maxMillisecondsPerRequest ) {
            $waitLonger = [math]::ceiling( $maxMillisecondsPerRequest - $t.TotalMilliseconds )
            "Waiting $( $waitLonger ) ms"
            Start-Sleep -Milliseconds $waitLonger
        }

        If ( $counter % 1000 ) {
            Write-Log -Message "Currently done $( $counter ) requests ($( $succeeded ) succeeded, $( $failed ) failed)" -Severity VERBOSE
        }

    }

    #Invoke-RestMethod -Uri "https://nominatim.openstreetmap.org/search?street=Franz-Delheid-Stra%C3%9Fe%2054&city=Aachen&postalcode=52080&format=jsonv2&accept-language=de&countrycodes=de&addressdetails=1&extratags=1"

    Write-Log -Message "Finished! Done $( $counter ) requests ($( $succeeded ) succeeded, $( $failed ) failed)" -Severity INFO

} catch {

    ################################################
    #
    # ERROR HANDLING
    #
    ################################################

    Write-Log -message "Got exception during execution phase" -severity ERROR
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ERROR
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ERROR
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ERROR
    
    # Check how many failures we have
    If ( $failed -le 10 ) {
        # Proceed
        Continue
        Write-Log -message "Continue - currently $( $failed ) failures" -severity WARNING
    } else {
        # Break out
        Write-Log -message "Breakout - too many failures" -severity WARNING
        throw $_.exception
        Break # maybe not needed
    }
    

} finally {

    $mssqlConnection.Close()

    ################################################
    #
    # RETURN
    #
    ################################################

    #$addresses | Out-GridView

}
