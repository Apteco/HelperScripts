
# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

If ( $configMode -and -not $settings) {

    # Don't load yet, when in config mode and settings object not yet available

} else {
    
    # Load all exe files in subfolder
    $libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
    $libExecutables | ForEach {
        "... $( $_.FullName )"
    
    }

    # Load dll files in subfolder
    $libDlls = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
    $libDlls | ForEach {
        "... $( $_.FullName )"
        #[Reflection.Assembly]::LoadFile($_.FullName) 
    }

}

Add-Type -AssemblyName System.Data #, System.Web  #, System.Text.Encoding
#Add-Type -AssemblyName System.Security





function Insert-Data {
    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$true)][System.Collections.ArrayList] $data
        #,[Parameter(Mandatory=$true)][System.Collections.ArrayList] $data

    )
    
    begin {
        
        # Build references to sqlite objects
        #$sqliteConnection = $event.MessageData.conn
        #$sqliteInsertCommand = $event.MessageData.insert
        Write-Host "Inserting $( $data.count ) records"
        Write-Host -Object ( $data | ConvertTo-Json -Depth 99 -Compress )
        #$colNames = $event.MessageData.columns

    }
    
    process {
        
        #-----------------------------------------------
        # INSERT DATA WITH TRANSACTION
        #-----------------------------------------------
            
        # Start transaction
        $sqliteTransaction = $sqliteConnection.BeginTransaction()

        # Insert data
        $inserts = 0
        $t = Measure-Command {

            try {

                # Insert the data
                $data | ForEach {
                    $row = $_
                    $colNames | ForEach {
                        $colName = $_
                        Write-Host ":$( $colName )"
                        $sqliteInsertCommand.Parameters[":$( $colName )"].Value = $row.$colName
                    }
                    $inserts += $sqliteInsertCommand.ExecuteNonQuery()
                    $sqliteInsertCommand.Reset()
                }

            } catch {

                throw $_

            } finally {

                # Commit the transaction
                $sqliteTransaction.Commit()

            }

        }

    }
    
    end {
            
        #-----------------------------------------------
        # LOG
        #-----------------------------------------------

        Write-Log -message "Inserted $( $inserts ) rows in $( $t.TotalSeconds ) seconds and will commit now"
        #$totalSeconds += $t.TotalSeconds

        # return
        $true

    }
}


function Update-Data {
    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$true)][System.Collections.ArrayList] $data
        #,[Parameter(Mandatory=$true)][System.Collections.ArrayList] $data

    )
    
    begin {
        
        # Build references to sqlite objects
        #$sqliteConnection = $event.MessageData.conn
        #$sqliteInsertCommand = $event.MessageData.insert
        #$colNames = $event.MessageData.columns
        Write-Host "Updating $( $data.count ) records"
        #Write-Host $sqliteUpdateFields
    }
    
    process {
        
        #-----------------------------------------------
        # UPDATE DATA WITH TRANSACTION
        #-----------------------------------------------
            
        # Start transaction
        $sqliteTransaction = $sqliteConnection.BeginTransaction()
        # Insert data
        $updates = 0
        $t = Measure-Command {

            try {

                # Insert the data
                $data | ForEach {
                    $row = $_
                    $sqliteUpdateFields | ForEach {
                        $colName = $_
                        Write-Host ":$( $colName )"
                        $sqliteUpdateCommand.Parameters[":$( $colName )"].Value = $row.$colName
                    }
                    Write-Host "Prepared command"
                    $updates += $sqliteUpdateCommand.ExecuteNonQuery()
                    $sqliteUpdateCommand.Reset()
                }

            } catch {

                throw $_

            } finally {

                # Commit the transaction
                $sqliteTransaction.Commit()

            }

        }

    }
    
    end {
            
        #-----------------------------------------------
        # LOG
        #-----------------------------------------------

        Write-Log -message "Updated $( $updates ) rows in $( $t.TotalSeconds ) seconds and will commit now"
        #$totalSeconds += $t.TotalSeconds

        # return
        $true

    }
}