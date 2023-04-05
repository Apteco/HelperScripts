Function Replace-Tokens {
    
    param(
         [Parameter(Mandatory=$true)][array]$InputString
        ,[Parameter(Mandatory=$true)][Hashtable]$Replacements
    )

    $newString = $InputString

    $Replacements.Keys | ForEach {
        $key = $_
        $newString = $newString -replace $key, $Replacements.$key
    }

    return $newString

}