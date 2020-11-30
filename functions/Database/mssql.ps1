

Function mssql-Load-Assemblies {
    Add-Type -AssemblyName System.Data
}

Function mssql-Open-Connection {
    
}

Function mssql-Load-DataTable {


    
    try {

        # build connection
        $mssqlConnection = New-Object "System.Data.SqlClient.SqlConnection"
        $mssqlConnection.ConnectionString = $mssqlConnectionString
        $mssqlConnection.Open()
        
        # execute command
        $campaignMssqlCommand = $mssqlConnection.CreateCommand()
        $campaignMssqlCommand.CommandText = $campaignSql
        $mssqlCommand.CommandTimeout = $settings.commandTimeout # TODO [ ] check this parameter exists
        $campaignMssqlResult = $campaignMssqlCommand.ExecuteReader()
        
        # load data
        $campaignMetadata = New-Object "System.Data.DataTable"
        $campaignMetadata.Load($campaignMssqlResult)
        #$customerMetadata.Load($customerMssqlResult, [System.Data.Loadoption]::Upsert)


    } catch [System.Exception] {

        $errText = $_.Exception
        $errText | Write-Output
        "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tError: $( $errText )" >> $logfile

    } finally {
        
        # close connection
        $mssqlConnection.Close()

    }


}

Function mssql-Upsert-DataTable {

    # build connection -> check if the connection can keeped open
    $mssqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $mssqlConnection.ConnectionString = $mssqlConnectionString
    $mssqlConnection.Open()

    $customerMetadata.rows | ForEach {
    
        $customer = $_

        # create customer object
        $customerLevel = New-Object PSCustomObject
        $customerLevel | Add-Member -MemberType NoteProperty -Name "Urn" -Value $customer.Urn
        $customerLevel | Add-Member -MemberType NoteProperty -Name "LevelBeforeUpdate" -Value $customer.LevelName
        $customerLevel | Add-Member -MemberType NoteProperty -Name "LevelToUpdate" -Value $levelToUpdate

        # prepare query
        $levelUpdateSql = Get-Content -Path ".\$( $levelUpdateSqlFilename )" -Encoding UTF8
        $levelUpdateSql = $levelUpdateSql -replace "#URN#", $customer.Urn
        $levelUpdateSql = $levelUpdateSql -replace "#LEVEL#", $levelToUpdate

        try {

            # execute command
            $levelUpdateMssqlCommand = $mssqlConnection.CreateCommand()
            $levelUpdateMssqlCommand.CommandText = $levelUpdateSql
            $levelUpdateSql
            $updateResult = $levelUpdateMssqlCommand.ExecuteScalar() #$mssqlCommand.ExecuteNonQuery()
    
        } catch [System.Exception] {

            $errText = $_.Exception
            $errText | Write-Output
            "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tError: $( $errText )" >> $logfile

        } finally {
    
           

        }



    }

    # close connection
    $mssqlConnection.Close()


}