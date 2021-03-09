
# https://stackoverflow.com/questions/4533570/in-powershell-how-do-i-split-a-large-binary-file
Function Split-File-To-Chunks {

    param(
        $inFile,
        $outPrefix,
        [Int32] $bufSize
    )

    $file = Get-Item -Path $inFile

    $stream = [System.IO.File]::OpenRead($inFile)
    $chunkNum = 1
    $barr = New-Object byte[] $bufSize
    
    $chunks = @()
    while( $bytesRead = $stream.Read($barr,0,$bufsize)){
      $outFile = "$( $file.DirectoryName )\$( $file.Name ).$( $outPrefix )$( $chunkNum )"
      $ostream = [System.IO.File]::OpenWrite($outFile)
      $ostream.Write($barr,0,$bytesRead);
      $ostream.close();
      #echo "wrote $outFile"
      $chunks += $outFile
      $chunkNum++
    }
    
    return ,$chunks # the comma enforces the function to return an array with one element rather than a string, if it is only one element

  }
