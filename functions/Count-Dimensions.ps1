Function Count-Dimensions {

    param(
        [Parameter(Mandatory=$true)]$var 
    )

    $return = 0
    if ( $var -is [array] ) {
        $add = Count-Dimensions -var $var[0]
        $return = $add + 1
    } 

    return $return

}