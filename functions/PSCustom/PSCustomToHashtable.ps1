
<#

Loaded from: https://stackoverflow.com/questions/3740128/pscustomobject-to-hashtable
But can also be found here by Adam Bertram: https://4sysops.com/archives/convert-json-to-a-powershell-hash-table/

#>
Function ConvertPSObjectToHashtable {

    [cmdletbinding()]
    [OutputType("Hashtable")]
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline)] $InputObject
    )

    process {

        if ( $null -eq $InputObject ) {
            # return
            return $null
        }

        if ( $InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [String] ) {

            $collection = @(
                $InputObject | ForEach {
                    $object = $_
                    ConvertPSObjectToHashtable $object
                }
            )
            # return
            Write-Output -NoEnumerate $collection

        } elseif ( $InputObject -is [PSObject] ) {
            
            $hash = [Hashtable]@{}
            $InputObject.PSObject.Properties | ForEach {
                $property = $_
                $hash[$property.Name] = ConvertPSObjectToHashtable $property.Value
            }
            # return
            $hash

        } else {

            # return
            $InputObject

        }

    }

}