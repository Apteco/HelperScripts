<#

reference: https://devops.ionos.com/api/s3/

implemented 

[ ]                s3 (accesskey, secretkey, region, service, url)
[ ]                |- getBuckets() Array of Buckets
[ ]                    |- Bucket
[ ]                        |- getObjects() Array of Objects
[ ]                            |- Object
[ ]                                |- delete()
[ ]                                |- download()
[ ]                                |- info()
[ ]                        |- upload()
[ ]                        |- delete()
[ ]                        |- versioning
[ ]                        |- versions
[ ]                |- addBucket()

... and more if needed

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

<#
    [String] toString() {
        return "Hello $( $this.name )"
    }
#>

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


    #-----------------------------------------------
    # CONSTRUCTORS
    #-----------------------------------------------
    
    S3Object () {

    }

    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------



}




