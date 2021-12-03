function Ask-Filepath {
    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$true)][String]$defaultPath   # The default path to ask for
        ,[Parameter(Mandatory=$true)][String]$filePrompt    # The name for the file that should be used in the prompt like "logfile"
    )
    
    begin {
      
        # Ask for another path
        $fileLocation = Read-Host -Prompt "Where do you want the $( $filePrompt ) file to be saved? Just press Enter for this default [$( $defaultPath )]"

    }
    
    process {

        # ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
        #$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

        # If prompt is empty, just use default path
        if ( $fileLocation -eq "" -or $null -eq $fileLocation) {
            $fileLocation = $defaultPath
        }


    }
    
    end {

        # TODO [ ] maybe loop here multiple times until the path is valid

        # Check if filename is valid
        if(Test-Path -LiteralPath $fileLocation -IsValid ) {
            Write-Host "Logfile '$( $fileLocation )' is valid"
            return $fileLocation
        } else {
            Write-Host "Logfile '$( $fileLocation )' contains invalid characters"
            throw [System.IO.FileNotFoundException]
        }

    }
    
}
