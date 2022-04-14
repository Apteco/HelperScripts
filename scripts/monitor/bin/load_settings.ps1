
# Load settings
$settings = Get-Content -Path $settingsFilename -Encoding UTF8 -Raw | ConvertFrom-Json #"$( $scriptPath )\$( $settingsFilename )"


#-----------------------------------------------
# MANUAL SETTINGS OVERRIDE
#-----------------------------------------------

#$maxAgeBeforeRemoval = 3
#$removeOldFilesAfterBackup = $true
<#

#>

#-----------------------------------------------
# FILES TO CHECK
#-----------------------------------------------


 $filesToCheck = [array]@(
    <#
    [PSCustomObject]@{
        "Name" = "db"
        "Path" = "C:\temp\Orbit\FastStatsSystemService\VarCodesCache-H_KW.db"
        "warningEvents" = @(
            "ZEROSIZE" # can be defined as string
            #[FILEEVENTS]::LOCKED # or like this
        )
    }
    #>

    [PSCustomObject]@{
        "Name" = "OrbitAPIConfigFile"
        "Path" = "C:\inetpub\wwwroot\OrbitAPI\OrbitAPIConfigurator.exe.config"
        "warningEvents" = @(
            "ZEROSIZE" # can be defined as string
            "LOCKED" # can be defined as string
            #[FILEEVENTS]::LOCKED # or like this
        )
    }

    

)

# TODO [ ] implement all warning events and actions and waitMinutesBeforeNextMail