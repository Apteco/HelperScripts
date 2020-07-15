

Function Invoke-SqlServer {

    param(
         [Parameter(Mandatory=$true)][String]$instance
        ,[Parameter(Mandatory=$true)][String]$database
        ,[Parameter(Mandatory=$true)][String[]]$query
        ,[Parameter(Mandatory=$false)][Switch]$executeScalar = $false
    )

    $connectionString = "Data Source=$( $instance );Initial Catalog=$( $database );Trusted_Connection=True;Connect Timeout=2400;"

    # build connection
    $connection = New-Object "System.Data.SqlClient.SqlConnection"
    $connection.ConnectionString = $connectionString
    $connection.Open()
   
   
                  
    try {

        # execute command
        $command = $connection.CreateCommand()
        $command.CommandText = $query
        
        If ( $executeScalar ) {
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