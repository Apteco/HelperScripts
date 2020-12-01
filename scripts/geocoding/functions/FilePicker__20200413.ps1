
<#

don't forget to use the assembly for this one with 
Add-Type -AssemblyName System.Windows.Forms


#>

Function Get-FileName($initialDirectory, $filter)
{
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = $filter
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename

}