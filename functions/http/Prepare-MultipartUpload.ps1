<#

# Do it with a file like a picture
$mp = Prepare-MultipartUpload -path "image.jpg"

# Do it directly with text information
$csv = import-csv "test.csv" -Encoding UTF8 -Delimiter ";"
$csvString = $csv | ConvertTo-Csv -Delimiter ";" -NoTypeInformation
$mp = Prepare-MultipartUpload -string $csvString


#>
function Prepare-MultipartUpload {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$false)][String]$path = "",
        [Parameter(Mandatory=$false)][String[]]$string = @(""),
        [Parameter(Mandatory=$false)]$part = $false
    )
    
    begin {
        
        if ( $path -eq "" -and $string -eq "" ) {
            throw [System.IO.InvalidDataException] "You must define either path or string. Both is empty"
        }

        # standard settings
        $uploadEncoding = "ISO-8859-1" #"UTF-8"
        $crlf = "`r`n";

        # Read a file()
        if ( $path -ne "" ) {
            # if multipart, remove the part prefix
            $fileItem = Get-Item -Path $path
            if ($part) {
                $fileName = $fileItem.Name.Substring(0, $fileItem.Name.lastIndexOf('.')) 
            } else {
                $fileName = $fileItem.Name
            }

            # get file, load and encode it
            $fileBytes = [System.IO.File]::ReadAllBytes($fileItem.FullName)

        }

        # Use a string
        if ( $string -ne "" ) {
            $oneString = $string -join $crlf
            $fileBytes = [Text.Encoding]::UTF8.GetBytes( $oneString )
            $filename = "$( [System.Guid]::NewGuid() ).txt"
        }

        # Encode the string
        $fileEncoded = [System.Text.Encoding]::GetEncoding($uploadEncoding).GetString($fileBytes)

    }
    
    process {
        


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

    }
    
    end {
        
        # put it together
        @{
            "body"=$body
            "contentType"="multipart/form-data; boundary=$( $boundary )"
        }

    }
}

