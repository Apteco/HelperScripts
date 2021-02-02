
<#

It can be called like:

$statementParams = @{
    "query" = $insertStatement
    "instance" = $settings.upload.databaseInstance
    "database" = $settings.upload.databaseName
    "executeNonQuery" = $true
}

if ( $settings.upload.trustedConnection ) {

    $statementParams += @{
        "trustedConnection" = $true
    }

} else {

    $securePass = ConvertTo-SecureString ( Get-SecureToPlaintext $settings.upload.databasePass ) -AsPlainText -Force
    $securePass.MakeReadOnly()
    $sqlcred = New-Object -TypeName System.Data.SqlClient.SqlCredential -ArgumentList $settings.upload.databaseUser, $securePass
    $statementParams += @{
        "sqlCredential" = $sqlCred
    }

}

$writtenRecords += Invoke-SqlServer @statementParams

#>
Function Invoke-SqlServer {

    param(
         [Parameter(Mandatory=$true)][String]$instance        
        ,[Parameter(Mandatory=$true)][AllowEmptyString()][String[]]$query
        ,[Parameter(Mandatory=$false)][String]$database = "master"
        ,[Parameter(Mandatory=$false)][System.Data.SqlClient.SqlCredential]$sqlCredential = $null
        ,[Parameter(Mandatory=$false)][Switch]$trustedConnection = $false
        ,[Parameter(Mandatory=$false)][Switch]$executeScalar = $false # Returns the first column in the first row
        ,[Parameter(Mandatory=$false)][Switch]$executeNonQuery = $false # Return the number of affected records (used for inserts, updates, deletes)
    )

#    $connectionString = "Data Source=$( $instance );Initial Catalog=$( $database );Trusted_Connection=True;Connect Timeout=2400;"
    $connectionString = "Data Source=$( $instance );Initial Catalog=$( $database );Connect Timeout=2400"
    If ( $trustedConnection ) {
        $connectionString += ";Trusted_Connection=True"
    }

    # build connection
    $connection = New-Object "System.Data.SqlClient.SqlConnection"
    $connection.ConnectionString = $connectionString
    if ( $trustedConnection -eq $false ) {
        $connection.Credential = $sqlCredential
    }
    $connection.Open()
   
   
                  
    try {

        # execute command
        $command = $connection.CreateCommand()
        $command.CommandText = $query
        
        
        If ( $executeNonQuery ) {
            $result = $command.ExecuteNonQuery()
        } elseif ( $executeScalar ) {
            $result = $command.ExecuteScalar()
        } else {
             # create datatable
            $result = new-object "System.Data.DataTable"
            $sqlResult = $command.ExecuteReader()
            # load data
            $result.Load($sqlResult, [System.Data.Loadoption]::Upsert)
        }
        


    } catch [System.Exception] {

        $errText = $_.Exception
        $errText | Write-Output
        Write-Log "Error: $( $errText )"

    } finally {
    
        # close connection
        $connection.Close() 

    }

    
    return $result

}
