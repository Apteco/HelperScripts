
"$( $args[0] )" | Set-Content -Path "$( $env:TEMP )\crcallback.txt" -Encoding utf8

################################################
#
# WAIT FOR KEY
#
################################################
<#
Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

exit 0
#>