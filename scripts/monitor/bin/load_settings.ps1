
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

    [PSCustomObject]@{
        "Name" = "db"
        "Path" = "C:\temp\Orbit\FastStatsSystemService\VarCodesCache-H_KW.db"
        "warningEvents" = @(
            "ZEROSIZE" # can be defined as string
            #[FILEEVENTS]::LOCKED # or like this
        )
    }
<#
    [PSCustomObject]@{
        "Name" = "test"
        "Path" = "C:\Users\Florian\Documents\GitHub\AptecoHelperScripts\scripts\hello.txt"
        "warningEvents" = @(
            "ZEROSIZE" # can be defined as string
            #[FILEEVENTS]::LOCKED # or like this
        )
        "actions" = @( # define what to do, when this event happens
            "MAIL"
        )
        "waitMinutesBeforeNextMail" = 0 # 0 = send every time; every other number, wait n minutes before re-adding this into a mail
    }
#>
)

# TODO [ ] implement all warning events and actions and waitMinutesBeforeNextMail