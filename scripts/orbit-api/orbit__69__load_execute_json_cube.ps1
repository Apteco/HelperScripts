
################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}
Set-Location -Path $scriptPath


################################################
#
# PREPARATION AND SESSION CREATION
#
################################################

. ".\orbit__60__preparation_for_examples.ps1"


################################################
#
# MISC ABOUT THE SYSTEM
#
################################################

#-----------------------------------------------
# SET DATAVIEW AND SYSTEM
#-----------------------------------------------

# Set DataView
$dataview = $settings.login.dataView

# Get Systems
$systems = Invoke-Apteco -key "GetFastStatsSystems" -additional @{dataViewName=$dataview}

# Choose system 
# TODO [ ] is viewName the correct one?
if ( $systems.totalCount -gt 1 ) {
    $system = ( $systems.list | Out-GridView -PassThru ).viewName
} elseif ( $systems.totalCount -eq 0 ) {
    "No systems"
    exit 0
} else {
    $system = $systems.list[0].viewName
}


#-----------------------------------------------
# CHOOSE FILEROOT
#-----------------------------------------------

# Get System root (private, public, cascade)
$systemRoot = Invoke-Apteco -key "GetRootFiles" -additional @{dataViewName=$dataview;systemName=$system}
$systemRoot.list | ft

# Choose a specific folder
$chooseRoot = $systemRoot.list | Out-GridView -PassThru
#$chooseRoot = $systemRoot.list | where { $_.name -eq "Private" }


#-----------------------------------------------
# LOAD FILES FROM A FOLDER
#-----------------------------------------------

# The parameters can also be defined in a separate object instead of the calling line
$params = @{
    dataViewName=$dataview
    systemName=$system
    directoryPath=$chooseRoot.path
    offset=10
    count=30
}
$files = Invoke-Apteco -key "GetFiles" -additional $params

# List the result
$files.list | ft

# Choose a file
$chooseFile = $files.list | where { $_.type -in @("Cube") } | Out-GridView -PassThru
#$chooseFile = $files.list | where { $_.name -eq "ActiveCustomers.xml" }


#-----------------------------------------------
# LOAD RAW CONTENT OF A CUBE
#-----------------------------------------------

$chosenFileContent = Invoke-Apteco -key "GetFile" -additional @{dataViewName=$dataview;systemName=$system;filePath=$chooseFile.path}
$chosenFileContent

exit 0

# TODO [ ] still work in progress after this point


#-----------------------------------------------
# TRANSFORM CUBE
#-----------------------------------------------

$convertedCube = [xml]$chosenFileContent.Substring(3) | Convert-XMLtoPSObject -attributesPrefix ""
$cube = $convertedCube.XmlSerialisationWrapper.Obj #| ConvertTo-Json -Depth 20

# Export cube content as json in a file
#$cube | ConvertTo-Json -Depth 20 | set-content -path "test.json" -Encoding UTF8

# Create cube for a count
$cubeTemplate = @{
    "baseQuery" = $cube.BaseQuery
    "resolveTableName" = $cube.Results.FastStatsCubeResult.FastStatsCube.CubeInfo.ResolveTable
    "storage" = $cube.Results.FastStatsCubeResult.FastStatsCube.CubeInfo.Storage
    "dimensions" = $cube.Results.FastStatsCubeResult.FastStatsCube.Dimensions.Dimension
    "measures" = @( $cube.Results.FastStatsCubeResult.FastStatsCube.Measures ) #.Measure
}


#-----------------------------------------------
# EXECUTE QUERY VIA JSON OBJECT
#-----------------------------------------------

# Show cube
$body = @{
    "cube" = $cubeTemplate
  }
$bodyJson = $body | ConvertTo-Json -Depth 20
$calculatedCube = Invoke-Apteco -key "CalculateCubeSync" -additional @{dataViewName=$dataview;systemName=$system} -body $bodyJson
#$chosenFileQuery.query | ConvertTo-Json -depth 20
