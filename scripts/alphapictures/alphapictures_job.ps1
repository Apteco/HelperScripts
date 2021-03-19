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
# DATA / VARIABLES FOR PERSONALISATION
#-----------------------------------------------

$data = @( # This is the data object which used in substitution, see below
    @{
        "firstname" = "John"
        "lastname" = "Doe"
        "number" = 101
    },
    @{
        "firstname" = "Foo"
        "lastname" = "Bar"
        "number" = 201
    }
)


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

# Add combined line
$lineNumbers = [System.Collections.ArrayList]@()
$selectedAlternative.lines | Get-Member -MemberType NoteProperty | ForEach {
    $lineNumbers.Add($_.Name)
}
$line = "Hello %firstname% %lastname%"

# Set size
$size = $selectedAlternative.original_rect -split ", "
$w = $size[2]
$h = $size[3]

# TODO [ ] generate the filename creation more flexible


#-----------------------------------------------
# CREATE JOB FOR BATCH IMAGE GENERATOR
#-----------------------------------------------

$body = [Ordered]@{
    "Images" = @( # Array of motifs that need to be rendered
        @{
            "MotifId" = $selectedAlternative."motif_id"
            "AlternativeId" = $selectedAlternative."alternative_id"
            "Template" = @{ # See below for explanation on template
                "$( $lineNumbers -join "+" )" = $line
            }
            "Filename" = "One_%number%" # Filename, without JPG extension
            "Dimensions" = @{ # Dimensions in pixels
                "w" = $w
                "h" = $h
            }
            "Watermark" = $useWatermark
        }
    )
    #"Callback" = "http://some.callback.com/" # HTTP callback called when job done
    "OutputOptions" = @{ # This are options related to the output of this job
        "OutputMethod" = "HOTLINK" # HOTLINK|ZIP
    }
    "Data" = $data
}


$params = @{
    Uri = "$( $baseUrl )Job"
    Method = "Post"
    Verbose = $true
    Headers = $headers
    Body = ConvertTo-Json -InputObject $body -Depth 8
    ContentType = "application/json; charset=UTF-8"
}

$job = Invoke-RestMethod @params

<#
{
    "JobId": "f5601144-a6d5-4008-b4be-1c3b3437f9e9",
    "Error": false,
    "Status": "IN_PROGRESS",
    "Key": "f81d4fae-7dec-11d0-a765-00a0c91e6bf6",
    "CDN": "http://cdn.alphapicture.com/f81d4fae-7dec-11d0-a765-00a0c91e6bf6/"
}
#>

exit 0

#-----------------------------------------------
# CHECK JOB STATUS
#-----------------------------------------------

$body = @{
    "Id" = $job.JobId
}

$params = @{
    Uri = "$( $baseUrl )JobInfo"
    Method = "Post"
    Verbose = $true
    Headers = $headers
    Body = ConvertTo-Json -InputObject $body -Depth 8
    #OutFile = ".\image.jpg"
    ContentType = "application/json; charset=UTF-8"
}

$jobInfo = Invoke-RestMethod @params



#-----------------------------------------------
# GET LINKS OR DOWNLOAD ZIP FILE
#-----------------------------------------------

$data.number | ForEach {
    
    $id = $_

    $params = @{
        #Uri = "$( $baseUrl )Result/$( $job.JobId )/One_$( $id )"
        Uri = "$( $job.CDN )/One_$( $id )"
        Method = "Get"
        Verbose = $true
        #Headers = $headers
        #Body = ConvertTo-Json -InputObject $body -Depth 8
        OutFile = ".\$( $id ).jpg"
        ContentType = "application/json; charset=UTF-8"
    }
    
    Invoke-RestMethod @params

}


