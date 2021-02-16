<#

reference: https://devops.ionos.com/api/s3/

implemented 

[x]                s3 (accesskey, secretkey, region, service, url)
[x]                |- getBuckets() Array of Buckets
[x]                    |- Bucket
[x]                        |- getObjects() Array of Objects
[x]                            |- Object
[x]                                |- delete()
[x]                                |- download()
[?]                                |- info()
[x]                        |- upload()
[ ]                        |- delete()
[ ]                        |- versioning
[x]                        |- versions
[ ]                |- addBucket()

... and more if needed



DEPENDENCIES

Get-StringHash.ps1 -> https://github.com/Apteco/HelperScripts/blob/master/functions/String/Get-StringHash.ps1


#>




class S3 {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    hidden [pscredential]$cred                 # holds the accesskey and secretkey
    [String]$baseUrl = "https://s3-de-central.profitbricks.com/"          # region
    [String]$region = "s3-de-central"          # region
    [String]$service = "s3"                    # service
    [PSCustomObject]$defaultParams


    #-----------------------------------------------
    # CONSTRUCTORS
    #-----------------------------------------------

    <#
    Notes from: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_object_creation?view=powershell-7
    You can create an object from a hash table of properties and property values.
    The syntax is as follows:
    [<class-name>]@{
    <property-name>=<property-value>
    <property-name>=<property-value>
    }
    This method works only for classes that have a parameterless constructor. The object properties must be public and settable.
    #>

    # empty default constructor needed to support hashtable constructor
    S3 () {
        $this.init()
    } 

    S3 ( [String]$accesskey, [String]$secret ) {
        $stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $secret ) -AsPlainText -Force
        $this.cred = [pscredential]::new( $accesskey, $stringSecure )
        $this.init()
    }

    S3 ( [String]$accesskey, [String]$secret, [String]$baseUrl, [String]$region ) {
        $stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $secret ) -AsPlainText -Force
        $this.cred = [pscredential]::new( $accesskey, $stringSecure )
        $this.baseUrl = $baseUrl
        $this.region = $region
        $this.init()
    }

    S3 ( [String]$accesskey, [String]$secret, [String]$baseUrl, [String]$region, [String]$service ) {
        $stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $secret ) -AsPlainText -Force
        $this.cred = [pscredential]::new( $accesskey, $stringSecure )
        $this.baseUrl = $baseUrl
        $this.region = $region
        $this.service = $service
        $this.init()
    }

    S3 ( [pscredential]$cred ) {
        $this.cred = $cred
        $this.init()
    }

    S3 ( [pscredential]$cred, [String]$baseUrl, [String]$region ) {
        $this.cred = $cred
        $this.baseUrl = $baseUrl
        $this.region = $region
        $this.init()
    }

    S3 ( [pscredential]$cred, [String]$baseUrl, [String]$region, [String]$service ) {
        $this.cred = $cred
        $this.baseUrl = $baseUrl
        $this.region = $region
        $this.service = $service
        $this.init()
    }


    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    hidden [void] init () {

        # Default Call parameters
        $this.defaultParams = @{
            "uri" = $this.baseUrl
            "region" = $this.region
            "service" = $this.service
            "cred" = $this.cred
        }

    }

    [PSCustomObject] getBuckets () {

        # Call parameters
        $params = $this.defaultParams + @{

        }
        
        # API Call
        $bucketsResult = Invoke-S3 @params

        # Transform result to objects
        $s3buckets = [System.Collections.ArrayList]@()
        $bucketsResult.ListAllMyBucketsResult.buckets.Bucket | ForEach {
            $b = $_
            $s3buckets.Add([S3Bucket]@{
                "creationDate" = $b.CreationDate
                "name" = $b.Name
                "s3" = $this
            })
        }

        # Return the results
        #return Convert-XMLtoPSObject -XML $buckets
        return $s3buckets
                
    }

<#
    listFiles() {

    }

    uploadFile( [String]Path ) {

    }

    downloadFile( [String]Path ) {

    }


    [String] toString()
    {
        return $this.sourceId, $this.sourceName -join $this.nameConcatChar
    }    
#>
}




class S3Bucket {


    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [String]$name
    [datetime]$creationDate
    hidden [S3]$s3


    #-----------------------------------------------
    # CONSTRUCTORS
    #-----------------------------------------------

    # Empty constructor for hashtable creation method
    S3Bucket () {

    }


    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------


    [PSCustomObject] getObjects () {

        # TODO [ ] check empty bucket -> NullReferenceException
        # TODO [ ] implement paging for more than 1k objects

        # Call parameters
        $params = $this.s3.defaultParams + @{
            "Bucket" = $this.name
        }

        # API Call
        $objectsResult = Invoke-S3 @params

        $s3objects = [System.Collections.ArrayList]@()
        $objectsResult.ListBucketResult.contents | ForEach {
            $o = $_
            $s3objects.Add([S3Object]@{
                "bucket" = $this
                "key" = $o.Key
                "lastModified" = $o.LastModified
                "storageClass" = $o.StorageClass
                "size" = $o.Size
                "eTag" = $o.ETag
                "owner" = $o.Owner
            })
        }

        # Return the results
        #return Convert-XMLtoPSObject -XML $objectsResult.ListBucketResult.contents
        return $s3objects
        
    }

    [PSCustomObject] getObjectsVersions () {

        # Call parameters
        $params = $this.s3.defaultParams + @{
            "Bucket" = $this.name
        }

        # Append versions
        $params.uri = "$( $params.uri )/?versions"

        # API Call
        $objectsResult = Invoke-S3 @params

        # TODO [ ] map this to objects
        # Return the results
        return Convert-XMLtoPSObject -XML $objectsResult.ListBucketResult.contents
        #return $s3objects
        
    }



    [System.Collections.ArrayList] upload( [String]$itemToUpload ) {
        
        # Remember the current location
        $loc = Get-Location 

        $itemsToUpload = [System.Collections.ArrayList]@()

        # Check if file
        if ( Test-Path -Path $itemToUpload -PathType Leaf  ) {

            $f = Get-Item -Path $itemToUpload
            $itemsToUpload.Add($f.FullName)
            Set-Location $f.Directory

        # Is directory
        } else {

            Set-Location $itemToUpload
            Get-ChildItem -Path $itemToUpload -Recurse -File | ForEach {
                $itemsToUpload.Add($_.FullName)
            }

        }

        $objectKeys = [System.Collections.ArrayList]@()
        $itemsToUpload | ForEach {

            $item = $_

            $objectkey = ( Resolve-Path -Path $item -Relative ) -replace "\.\\","" -replace "\\","/"
            
            # Call parameters
            $params = $this.s3.defaultParams + @{
                "Bucket" = $this.name
                "objectKey" = $objectkey
                "localfile" = $item
                "verb" = "PUT"
            }
            
            # Upload
            try {

                Invoke-S3 @params

            } catch {

            }

            $objectKeys.Add($objectkey)

        }
        #$fileToUpload = "C:\Users\Florian\Downloads\nathan-dumlao-zUNs99PGDg0-unsplash.jpg"


        # Change back to the current location
        Set-Location -Path $loc
        
        # TODO [ ] implement returning the uploaded s3object instead of the key (but requires an additional api call)
        return $objectKeys

    }

}






class S3Object {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

<#
    Key          : nathan-dumlao-zUNs99PGDg0-unsplash.jpg
    LastModified : 2021-02-15T16:58:19.954Z
    StorageClass : STANDARD
    Size         : 4802304
    ETag         : "da0b7b8b17f2b993d46dfe80fd40656d"
    Owner        : @{ID=6e100....; DisplayName=email@example.org}
#>

    [String]$key
    [datetime]$LastModified
    [String]$storageClass
    [int]$size
    [String]$eTag
    [PSCustomObject]$owner

    hidden [S3Bucket]$bucket


    #-----------------------------------------------
    # CONSTRUCTORS
    #-----------------------------------------------
    
    S3Object () {

    }

    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    # TODO [ ] Implement destination as directory or filename

    [System.IO.FileInfo] download( [String]$outputfolder ) {

        $pathParts = $this.key -split "/" 
        $filename = $pathParts[-1]
        #$destination = "$( $outputfolder )" #\$( $filename )"
        #$tempFilename = "$( $filename ).tmp"
    
        $params = $this.bucket.s3.defaultParams + @{
            "Bucket" = $this.bucket.name
            "objectKey" = $this.key
            "localfile" = $outputfolder
            "contentType" = [System.Web.MimeMapping]::GetMimeMapping($filename)
            "keepFolderStructure" = $true
        }
        
        try {
            Invoke-S3 @params
        } catch {

        }

        $path = $outputfolder
        $pathParts | ForEach {
            $part = $_
            $path = Join-Path $path -ChildPath $part #-Resolve
        }

        return ( Get-Item -Path "$( $path  )" )
        
    }
<#
    getInfo() {

        $params = $this.bucket.s3.defaultParams + @{
            "Bucket" = $this.bucket.name
            "objectKey" = $this.key
            "verb" = "HEAD"
        }
    
        $res = Invoke-S3 @params


    }
#>
    [void] remove() {

        $params = $this.bucket.s3.defaultParams + @{
            "Bucket" = $this.bucket.name
            "objectKey" = $this.key
            "verb" = "DELETE"
        }
    
        Invoke-S3 @params

    }

}




################################################
#
# FUNCTIONS
#
################################################


function Invoke-S3 {

    [CmdletBinding()]
    param (

         [Parameter(Mandatory=$false)][string]$bucket = ""
        ,[Parameter(Mandatory=$false)][String]$verb = "GET"
        ,[Parameter(Mandatory=$false)][string]$objectKey = ""                                       # the key/path to the file in the bucket
        ,[Parameter(Mandatory=$false)][string]$localfile = ""                                       # the local file to upload or download destination
        ,[Parameter(Mandatory=$false)][string]$contentType = "text/plain"                           # default content type
        ,[Parameter(Mandatory=$false)][System.Uri]$uri = "https://s3-de-central.profitbricks.com/"  # default url to use
        #,[Parameter(Mandatory=$false)][Switch]$storeEncrypted = $false                              # TODO [ ] implement this flag
        ,[Parameter(Mandatory=$false)][Switch]$keepFolderStructure = $true                          # keep the folder when downloading files
        ,[Parameter(Mandatory=$false)][Switch]$overwriteLocalfile = $false                          # should the local file overridden if already existing?
        ,[Parameter(Mandatory=$false)][String]$region = "s3-de-central"                             # 
        ,[Parameter(Mandatory=$false)][String]$service = "s3"                                       # 
        ,[Parameter(Mandatory=$false)][pscredential]$cred                                           # securestring containing accesskey as user and secret as password

    )

    begin {

        #-----------------------------------------------
        # PREPARE
        #-----------------------------------------------

        # date operations
        $currentDate = Get-Date #-Year 2020 -Month 01 -Day 01 -Hour 12 -Minute 00 -Second 00 -Millisecond 00 #Get-Date
        $date = $currentDate.ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
        $dateStamp = $currentDate.ToUniversalTime().ToString("yyyyMMdd")

        # setup scope
        $scope = "$( $dateStamp )/$( $region )/$( $service )/aws4_request"

        # Sanitize strings
        $verbUpper = $verb.ToUpper()
        $escapedObjectKey = [uri]::EscapeDataString($objectKey) -replace "%2F","/"

        # add bucket and dot if it is used
        [System.Uri]$endpoint = "$( $uri.Scheme )://$( $bucket )$( if ($bucket -ne '') { '.' } )$( $uri.Host )/$( $escapedObjectKey )"

        # file hash for upload, otherwise hash of empty string
        if ( $verbUpper -eq "PUT" -and $localfile -ne "") {           
            # work out hash value
            $contentHash = (( Get-FileHash $localfile -Algorithm "SHA256" ).Hash ).ToLower()
        } else {
            $contentHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }

        # credentials
        $secret = $cred.GetNetworkCredential().Password
        $accesskey = $cred.UserName

        

    }

    process {
        
        #-----------------------------------------------
        # CANONICAL REQUEST
        #-----------------------------------------------

        #$canonicalRequestPlain = "$( $verbUpper )`n/$( $escapedObjectKey )`n`ncontent-type:$( $contentType )`nhost:$( $endpoint.Host )`nx-amz-content-sha256:$( $contentHash )`nx-amz-date:$( $date )`n`ncontent-type;host;x-amz-content-sha256;x-amz-date`n$( $contentHash )"
        # Be careful with herestrings -> the file format of your script ("LF" is the correct one!) makes the different. Using CRLF can cause problems
        # if you use the here string and convert it to bytes
        $canonicalRequestPlain = @"
$( $verbUpper )
/$( $escapedObjectKey )

content-type:$( $contentType )
host:$( $endpoint.Host )
x-amz-content-sha256:$( $contentHash )
x-amz-date:$( $date )

content-type;host;x-amz-content-sha256;x-amz-date
$( $contentHash )
"@

        $canonicalRequestHash = Get-StringHash -inputString $canonicalRequestPlain -hashName "SHA256"


        #-----------------------------------------------
        # STRING TO SIGN
        #-----------------------------------------------
        
        $stringToSign = "AWS4-HMAC-SHA256`n$( $date )`n$( $scope )`n$( $canonicalRequestHash )"


        #-----------------------------------------------
        # SIGNATURE KEY
        #-----------------------------------------------

        $ksecret = "AWS4$( $secret )"
        $kDate = Get-StringHash -inputString $dateStamp -hashName "HMACSHA256" -key $ksecret
        $kRegion = Get-StringHash -inputString $region -hashName "HMACSHA256" -key $kDate -keyIsHex
        $kService = Get-StringHash -inputString $service -hashName "HMACSHA256" -key $kRegion -keyIsHex
        $sign = Get-StringHash -inputString "aws4_request" -hashName "HMACSHA256" -key $kService -keyIsHex


        #-----------------------------------------------
        # SIGNATURE
        #-----------------------------------------------

        # Combines "String to sign" with the "Signature Key"
        $signatureHash = Get-StringHash -inputString $stringToSign -hashName "HMACSHA256" -key $sign -keyIsHex
        

        #-----------------------------------------------
        # HEADERS
        #-----------------------------------------------

        $headers = @{
            "Host" = $endpoint.Host
            "Content-Type" = $contentType
            "x-amz-content-sha256" = $contentHash
            "x-amz-date" = $date
            "Authorization" = "AWS4-HMAC-SHA256 Credential=$($accesskey)/$($scope),SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date,Signature=$( $signatureHash )"
        }


        #-----------------------------------------------
        # PREPARE LOCAL STRUCTURE
        #-----------------------------------------------


        if ( $localfile -ne "") {

            # Create folder structure if wished
            if ( $verbUpper -eq "PUT") {
                
                $localFilepath = Resolve-Path -Path $localfile

            } else {

                $p = Get-Item -Path $localfile
                $path = $p.FullName  # TODO [x] maybe change to another root folder
                $pathParts = $objectKey -split "/" 
                $tempFilename = "$( $pathParts[-1] ).tmp"

                if ( $keepFolderStructure ) {

                    # Build new folder structure
                    $pathParts | select -SkipLast 1 | ForEach {
                        $part = $_
                        $path = Join-Path $path -ChildPath $part #-Resolve
                    }

                    # Create that structure
                    #$resolvedPath = Resolve-Path -Path $path -
                    if ( $pathparts.count -gt 1 -and !(Test-Path -Path $path) ) {
                        New-Item -Path $path -ItemType Directory
                    }
        
                } 

                $localFilepath = Join-Path -Path $path -ChildPath $tempFilename #$pathParts[-1] 
                $finalFilepath = Join-Path -Path $path -ChildPath $pathParts[-1]

    
            }


        }

        #-----------------------------------------------
        # CALL API
        #-----------------------------------------------

        # Default Call
        $callParams = @{
            uri = $endpoint
            method = $verbUpper
            headers = $headers
            verbose = $true
        }

        # Choose if file should be uploaded or downloaded
        if ( $localfile -ne "" ) {
            if ( $verbUpper -eq "PUT" ) {
                $callParams += @{
                    InFile = $localFilepath
                }
            } else {
                $callParams += @{
                    OutFile = $localFilepath
                }
            }
        }



        $result = Invoke-RestMethod @callParams

        #-----------------------------------------------
        # FILES WRAP UP
        #-----------------------------------------------

        # Remove file if already exists
        if ( $localfile -ne "" -and $verbUpper -ne "PUT") {
            if ( $overwriteLocalfile ) {
                Remove-Item -Path $finalFilepath -Force
            }    
            Move-Item -Path $localFilepath -Destination $finalFilepath
        }

    }
    
    end {
        
        #-----------------------------------------------
        # RETURN RESULT
        #-----------------------------------------------

        $result

    }

}