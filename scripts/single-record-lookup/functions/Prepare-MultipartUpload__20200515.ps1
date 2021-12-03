

Function Prepare-MultipartUpload {
    param(
        [Parameter(Mandatory=$true)][String]$path,
        [Parameter(Mandatory=$false)]$part = $false
    )

    # standard settings
    $uploadEncoding = "ISO-8859-1"
    $crlf = "`r`n";
    
    # if multipart, remove the part prefix
    $fileItem = Get-Item -Path $path
    if ($part) {
        $fileName = $fileItem.Name.Substring(0, $fileItem.Name.lastIndexOf('.')) 
    } else {
        $fileName = $fileItem.Name
    }
    
    # get file, load and encode it
    $fileBytes = [System.IO.File]::ReadAllBytes($fileItem.FullName);
    $fileEncoded = [System.Text.Encoding]::GetEncoding($uploadEncoding).GetString($fileBytes);

    # create guid for multipart upload
    $boundary = [System.Guid]::NewGuid().ToString(); 

    # create body
    $body = ( 
        "--$( $boundary )",
        "Content-Disposition: form-data; name=`"file`"; filename=`"$( $fileName )`"",
        "Content-Type: application/octet-stream$( $crlf )",
        $fileEncoded,
        "--$( $boundary )--$( $crlf )" 
    ) -join $crlf

    # put it together
    @{
        "body"=$body
        "contentType"="multipart/form-data; boundary=""$( $boundary )"""
    }

}