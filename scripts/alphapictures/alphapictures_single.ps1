#-----------------------------------------------
# SETTINGS
#-----------------------------------------------

$headers = @{
    "APIV4-Account" = "<username>"
    "APIV4-Password" = "<password>"
}

$baseUrl = "https://v4.alphapicture.com/"
$useWatermark = $false


#-----------------------------------------------
# GET MOTIFS
#-----------------------------------------------

$params = @{
    Uri = "$( $baseUrl )Motifs"
    Method = "Get"
    Verbose = $true
    Headers = $headers
    ContentType = "application/json; charset=UTF-8"
}

$motifs = Invoke-RestMethod @params


#-----------------------------------------------
# PERSONALISATION FOR MOTIF
#-----------------------------------------------

# Choose motiv
$selectedMotif = $motifs | Out-GridView -PassThru | select -First 1
$selectedMotif

# Choose alternative
$selectedAlternative = $selectedMotif.alternatives | Out-GridView -PassThru | select -first 1

# Add lines
$lines = [PSCustomObject]@{}
$selectedAlternative.lines | Get-Member -MemberType NoteProperty | ForEach {
    $lineNumber = $_.Name
    $lineText = Read-Host -Prompt "Please enter the text for line $( $lineNumber )"
    $lines | Add-Member -MemberType NoteProperty -Name $lineNumber -Value $lineText
}

# Set size
$size = $selectedAlternative.original_rect -split ", "
$w = $size[2]
$h = $size[3]


#-----------------------------------------------
# DOWNLOAD IMAGE
#-----------------------------------------------

$body = [Ordered]@{
    "MotifId" = $selectedAlternative."motif_id" # Id of the motif
    "AlternativeId" = $selectedAlternative."alternative_id" # Alternative Id
    "Lines" = $lines
    "Dimensions" = @{ # Dimensions in pixels
        "w" = $w
        "h" = $h
    }
    <#
    "SourceRect" = @{ # Optional: SourceRect is for retrieving a certain cut-out of the original image
        "x1" = 1532
        "y1" = 1353
        "x2" = 3801
        "y2" = 2195
    }
    #>
    "Watermark" = $useWatermark # Optional: set to true if image should be watermarked
}

$params = @{
    Uri = "$( $baseUrl )Image"
    Method = "Post"
    Verbose = $true
    Headers = $headers
    Body = ConvertTo-Json -InputObject $body -Depth 8
    OutFile = ".\image.jpg"
    ContentType = "application/json; charset=UTF-8"
}

$image = Invoke-RestMethod @params