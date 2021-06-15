
<#
EXAMPLES


$str = "https://www.apteco.de/test/123?abc=def&xyz=uuu"
Add-HttpQueryPart -Uri $str -QueryParameter @{name="klj";desc="xzy"}

#>

# Inspired by https://powershellmagazine.com/2019/06/14/pstip-a-better-way-to-generate-http-query-strings-in-powershell/
function Add-HttpQueryPart
{
    [CmdletBinding()]
    param 
    (
         [Parameter(Mandatory=$true)][String]$Uri
        ,[Parameter(Mandatory=$true)][Hashtable]$QueryParameter
    )
    
    # Add System.Web
    Add-Type -AssemblyName System.Web
    
    # Parse existing URI
    $u = [System.Uri]::new($Uri)

    # Create a http name value collection from an empty string
    $nvCollection = [System.Web.HttpUtility]::ParseQueryString( $u.Query )
    
    # Parse uri without query
    if ( $nvCollection.count -gt 0 ) {
        $uriWithoutQuery = $u.OriginalString.replace($u.Query, "")
    } else {
        $uriWithoutQuery = $u.OriginalString
    }

    # Add key/value from input hashtable
    foreach ($key in $QueryParameter.Keys) {
        $nvCollection.Add($key, $QueryParameter.$key)
    }
    
    # Build the uri
    $uriRequest = [System.UriBuilder]$uriWithoutQuery
    $uriRequest.Query = $nvCollection.ToString()
    
    return $uriRequest.Uri.OriginalString
}

