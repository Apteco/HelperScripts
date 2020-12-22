
<#
Is-Numeric 10       # True
Is-Numeric "10"     # True
Is-Numeric "10f"    # False
Is-Numeric "+10"    # True
Is-Numeric "-10"    # True
Is-Numeric "-10.5"  # False
#>
function Is-Int ($value) {
    return $value -match "^[+-]?[\d]+$"
}

<#
Is-Float 10       # False
Is-Float "10"     # False
Is-Float "10."    # False
Is-Float "10.5"   # True
Is-Float "10.545" # True
Is-Float "+10.5"   # True
Is-Float "-10.5"   # True
#>
function Is-Float () {
    return $value -match "^[+-]?[\d]+[\.]+[\d]+$"
}

<#
# This should be True
Is-Link "https://www.apteco.com/blog?customerId=123"

# This should be False
Is-Link "ftp://www.google.com"
#>
function Is-Link ($value) {
    $regexForLinks = "(http[s]?)(:\/\/)({{(.*?)}}|[^\s,])+"
    $containedLinks = [Regex]::Matches($value, $regexForLinks) | Select -ExpandProperty Value
    return $containedLinks.count -eq 1
}