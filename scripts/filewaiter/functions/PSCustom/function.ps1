function Get-FunctionString
{
[CmdletBinding()]
param
(
[Parameter(Mandatory = $true)][System.Array] $Function
)
 
[string]$strFunctions = $null
$items = Get-ChildItem Function:\ | Where Name -in $Function
 
ForEach ($item in $items)
{
$strFunctions += "Function $($item.Name) { `r`n $($item.Definition) `r`n }`r`n"
}
 
$strFunctions
 
}