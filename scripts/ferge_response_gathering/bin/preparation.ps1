
# Some more settings

$ferge = $settings.fergeExe
$gathererConfig = $settings.fergeConfig

# Folder check

if ( !(Test-Path -Path $settings.detailsSubfolder) ) {
    New-Item -Path "$( $settings.detailsSubfolder )" -ItemType Directory
}