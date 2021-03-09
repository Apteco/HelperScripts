

Function Prepare-MultipartUpload {
    param(
        [Parameter(Mandatory=$true)][String]$path,
        [Parameter(Mandatory=$false)]$part = $false
    )

    # standard settings
    $uploadEncoding = "ISO-8859-1" #"UTF-8"
    $crlf = "`r`n";
    
    # if multipart, remove the part prefix
    $fileItem = Get-Item -Path $path
    if ($part) {
        $fileName = $fileItem.Name.Substring(0, $fileItem.Name.lastIndexOf('.')) 
    } else {
        $fileName = $fileItem.Name
    }
    
    # get file, load and encode it
    $fileBytes = [System.IO.File]::ReadAllBytes($fileItem.FullName)
    $fileEncoded = [System.Text.Encoding]::GetEncoding($uploadEncoding).GetString($fileBytes)

    # create guid for multipart upload
    $boundary = [System.Guid]::NewGuid().ToString().replace("-","").PadLeft(57,"-")

    # Get the mime type
    $mimeType = [System.Web.MimeMapping]::GetMimeMapping($fileName)

    # create body
    $body = (
        #"multipart/form-data; boundary=$( $boundary )",
        "--$( $boundary )",
        "Content-Disposition: form-data; name=`"file`"; filename=`"$( $fileName )`"",
        "Content-Type: $( $mimeType )$( $crlf )",
        #"Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet$( $crlf )",
        $fileEncoded,
        "--$( $boundary )--$( $crlf )" 
    ) -join $crlf

    # put it together
    @{
        "body"=$body
        "contentType"="multipart/form-data; boundary=$( $boundary )"
    }

}

