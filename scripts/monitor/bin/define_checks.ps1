
#-----------------------------------------------
# DEFINE POSSIBLE EVENTS AND ACTIONS
#-----------------------------------------------

# possible file events
Enum FILEEVENTS {
    ZEROSIZE   = 0
    #OUTDATED   = 10
    LOCKED     = 20
    #TOOBIG      = 30
}

# possible folder events
Enum FOLDEREVENTS {
    #EMPTY   = 0
    #TOOMANYFILES = 10
}

# possible actions to undertake
# TODO [ ] implement those actions
Enum ACTIONS {
    MAIL = 0                # send a mail
    #DELETEFILE = 10         # delete the file
    #DELETEFOLDER = 20       # delete the folder with all contents
    #EMPTYFOLDER = 30        # empty the whole folder
    #DELETEUNTILMAXAGE = 40  # keep some entries in a folder for a max of n days
    #RESTARTSERVICE
    #EXECUTEQUERY
    #RESTARTAPPPOOL

}


#-----------------------------------------------
# DEFINE THE SCRIPTS TO CHECK EVENTS
#-----------------------------------------------


<#
                # Check some meta data
                $item.IsReadOnly
                $item.LastAccessTime
                $item.CreationTime
                $item.LastWriteTime
                $item.Length
                $item.PSIsContainer

                    $warningEvent
#>


$eventChecks = [hashtable]@{

    [FILEEVENTS]::ZEROSIZE.toString() = [scriptblock]{ #( [FILEEVENTS]::ZEROSIZE )

        param(
            $path
        )

        $item = Get-Item -Path $path

        If ( $item.PSIsContainer -eq $true ) {
                                        
            $msg = "$( $timestamp.ToString("dd.MM.yyyy HH:mm:ss") ) - You defined 'ZEROSIZE' for '$( $item.FullName )', but this is a folder, not a file. Please choose another warning"
            Write-log -message $msg -severity ([LogSeverity]::WARNING)
            [void]$warningEntries.Add($msg)
        
        } else {
            
            If ( $item.Length -eq 0 ) {
        
                $msg = "$( $timestamp.ToString("dd.MM.yyyy HH:mm:ss") ) - The item triggered 'ZEROSIZE' for '$( $item.FullName )'"
                Write-log -message $msg -severity ([LogSeverity]::WARNING)
                [void]$warningEntries.Add($msg)
                    
            }
            
        }
    }

    [FILEEVENTS]::LOCKED.ToString() = [scriptblock]{

        # Reference to: https://stackoverflow.com/questions/24992681/powershell-check-if-a-file-is-locked

        param(
            $path
        )

        $item = Get-Item -Path $path

        If ( $item.PSIsContainer -eq $true ) {
                                        
            $msg = "$( $timestamp.ToString("dd.MM.yyyy HH:mm:ss") ) - You defined 'LOCKED' for '$( $item.FullName )', but this is a folder, not a file. Please choose another warning"
            Write-log -message $msg -severity ([LogSeverity]::WARNING)
            [void]$warningEntries.Add($msg)
        
        } else {
            
            # Check if file is locked
            $oFile = [System.IO.FileInfo]::new($path) #New-Object System.IO.FileInfo $path
            try {
                $oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)        
                if ($oStream) {
                $oStream.Close()
                }            
                $locked = $false
            } catch {
                # file is locked by a process.
                $locked = $true
            }

            # Create warning
            If ( $locked -eq $true ) {
                                            
                $msg = "$( $timestamp.ToString("dd.MM.yyyy HH:mm:ss") ) - The item triggered 'LOCKED' for '$( $item.FullName )'"
                Write-log -message $msg -severity ([LogSeverity]::WARNING)
                [void]$warningEntries.Add($msg)
            
            } 
            
        }        

    }



}

#-----------------------------------------------
# DEFINE THE ACTIONS IF EVENTS HAPPEN
#-----------------------------------------------

$eventActions = [hashtable]@{

    [ACTIONS]::MAIL.ToString() = [scriptblock]{

    }

}

