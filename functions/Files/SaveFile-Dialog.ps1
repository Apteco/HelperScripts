<#

draft from: https://gist.github.com/talatham/5773769
and improved here

Set-FileName
Set-FileName -initialDirectory C:\temp
Set-FileName -initialDirectory $env:LOCALAPPDATA
Set-FileName -initialDirectory $env:LOCALAPPDATA -filter "Text files (*.txt)|*.txt"
Set-FileName -initialDirectory $env:LOCALAPPDATA -filter "txt files (*.txt)|*.txt|All files (*.*)|*.*"

If the user presses "cancel", the value is $null so you can check it by:
$filename = Set-FileName
if ( $filename -eq $null ) {
    "the user canceled the dialog"
}


#>


Function Set-Filename {
    [CmdletBinding()]
    param(
         [Parameter(Mandatory=$false)][string]$initialDirectory = "C:\"
        ,[Parameter(Mandatory=$false)][string]$filter = "All files (*.*)|*.*"
        #[Parameter(Mandatory=$true)][string]$hashName,
        #[Parameter(Mandatory=$false)][string]$salt,
        #[Parameter(Mandatory=$false)][boolean]$uppercase=$false
    )

    
    begin {
        $chosenFile = $null
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    }
    
    process {

        # Settings for the popup
        $saveFileDialog.initialDirectory = $initialDirectory
        $saveFileDialog.Filter = $filter

        
        # Show the dialog
        if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $chosenFile = $saveFileDialog.FileName
        }
    
    }
    
    end {

        # return the results
        $chosenFile
    }
}


