Function Query-SQLServer {

    param(
         [Parameter(Mandatory=$true)][System.Data.SqlClient.SqlConnection]$connection 
        ,[Parameter(Mandatory=$true)][string]$query 
    )

    try {

        # build connection
        #$mssqlConnection = New-Object "System.Data.SqlClient.SqlConnection"
        #$mssqlConnection.ConnectionString = $connectionString 
        #$mssqlConnection.Open()
        
        # execute command
        $mssqlCommand = $connection.CreateCommand()
        $mssqlCommand.CommandText = $query
        $mssqlCommand.CommandTimeout = $settings.commandTimeout
        $mssqlResult = $mssqlCommand.ExecuteReader()
        
        # load data
        $result = [System.Data.DataTable]::new()
        $result.Load($mssqlResult)

        # return result datatable
        return $result

    } catch [System.Exception] {

        $errText = $_.Exception
        $errText | Write-Output
        #Write-Log -message "Error: $( $errText )"

    } finally {
        
        # close connection
        #$mssqlConnection.Close()

    }

}

Function NonQuery-SQLServer {

    param(
         [Parameter(Mandatory=$true)][System.Data.SqlClient.SqlConnection]$connection 
        ,[Parameter(Mandatory=$true)][string]$command 
    )

    try {

        # build connection
        #$mssqlConnection = New-Object "System.Data.SqlClient.SqlConnection"
        #$mssqlConnection.ConnectionString = $connectionString 
        #$mssqlConnection.Open()
        
        # execute command
        $mssqlCommand = $connection.CreateCommand()
        $mssqlCommand.CommandText = $command
        $mssqlCommand.CommandTimeout = $settings.commandTimeout
        $result = $mssqlCommand.ExecuteNonQuery()
        
        # return result datatable
        return $result

    } catch [System.Exception] {

        $errText = $_.Exception
        $errText | Write-Output
        #Write-Log -message "Error: $( $errText )"

    } finally {
        
        # close connection
        #$mssqlConnection.Close()

    }

}


Function NonQueryScalar-SQLServer {

    param(
         [Parameter(Mandatory=$true)][System.Data.SqlClient.SqlConnection]$connection 
        ,[Parameter(Mandatory=$true)][string]$command 
    )

    try {

        # build connection
        #$mssqlConnection = New-Object "System.Data.SqlClient.SqlConnection"
        #$mssqlConnection.ConnectionString = $connectionString 
        #$mssqlConnection.Open()
        
        # execute command
        $mssqlCommand = $connection.CreateCommand()
        $mssqlCommand.CommandText = $command
        $mssqlCommand.CommandTimeout = $settings.commandTimeout
        $result = $mssqlCommand.ExecuteScalar()
        
        # return result datatable
        return $result

    } catch [System.Exception] {

        $errText = $_.Exception
        $errText | Write-Output
        #Write-Log -message "Error: $( $errText )"

    } finally {
        
        # close connection
        #$mssqlConnection.Close()

    }

}

<#

Notes for bulk copy

    try {

    $sqlBulkCopy = New-Object -TypeName System.Data.SqlClient.SqlBulkCopy($mssqlConnectionString, [System.Data.SqlClient.SqlBulkCopyOptions]::KeepIdentity)
    #$sqlBulkCopy.EnableStreaming = $true
    $sqlBulkCopy.DestinationTableName = $bulkDestination
    $sqlBulkCopy.BatchSize = $settings.bulkBatchsize
    $sqlBulkCopy.BulkCopyTimeout = $settings.bulkTimeout
    $bulkResult = $sqlBulkCopy.WriteToServer($campaignMetadata)

    } catch [System.Exception] {

        $errText = $_.Exception
        $errText | Write-Output
        Write-Log -message "Error: $( $errText )"

    } finally {

        $sqlBulkCopy.Close()

    }

#>