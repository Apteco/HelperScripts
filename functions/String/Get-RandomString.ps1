function getRandomString([int] $length) {
    $random = [Random]::new()
    $chars = @("0", "2", "3", "4", "5", "6", "8", "9", "a", "b", "c", "d", "e", "f", "g", "h", "j", "k", "m", "n", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z")
    $stringBuilder = ""
    for ($i = 0; $i -lt $length; $i++) {
        $stringBuilder += $chars[$random.Next($chars.Length)]
    }
    return $stringBuilder
}