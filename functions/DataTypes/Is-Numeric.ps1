

Function Is-Numeric {

    param(
        [Parameter(Mandatory=$true)]$Value
    )

    return $Value -match "^[\d\.]+$"
}