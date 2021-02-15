
<#

# Example creates something like
# VrmpwjSjKEADWe+rv4CF+KrZ
Get-RandomString -length 24

#>
function Get-RandomString() {

    [cmdletbinding()]
    param(
         [Parameter(Mandatory=$true)][int]$length
    )
   
    begin {

        $random = [Random]::new()

        # Add characters to use
        $chars = @("0", "2", "3", "4", "5", "6", "8", "9")
        $chars += @("a", "b", "c", "d", "e", "f", "g", "h", "j", "k", "m", "n", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z")
        $chars += @("A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z")
        $chars += @("*", "#","=","-","+","|","~")

    }
    
    process {
        $stringBuilder = ""
        for ($i = 0; $i -lt $length; $i++) {
            $stringBuilder += $chars[$random.Next($chars.Length)]
        }
    }
    
    end {
        $stringBuilder
    }

}



# deprecated function name
function getRandomString() {
    [cmdletbinding()]
    param(
         [Parameter(Mandatory=$true)][int]$length
    )
    Get-RandomString($length)
}

