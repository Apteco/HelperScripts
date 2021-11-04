# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        [System.Net.SecurityProtocolType]::Tls13
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}