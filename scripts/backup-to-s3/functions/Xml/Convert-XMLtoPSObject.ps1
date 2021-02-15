<#
.SYNOPSIS
  Conversion of valid xml into a PSCustomObject, so it can be easily used to create json instead
.DESCRIPTION
  Inspired from the C# example from: Translated into PowerShell from https://dev.to/adamkdean/xml-to-hashtable-59dg
  This script uses xml input and converts all tags and attributes into a PSCustomObject.
  This allows a much easier transformation into a json object.
.EXAMPLE

# Using this input xml (could also be a file) ...

$xmlInputString = @"
<?xml version="1.0" encoding="utf-8"?>
<XmlSerialisationWrapper xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xml:space="preserve">
    <CurrentDate>20201130</CurrentDate>
    <Location>Germany</Location>
    <Messages errors="0" warnings="0" info="1">All fine!</Messages>
    <Obj xsi:type="TablePersistentState">
        <Book id="123">
            <Title>Book Nr 1</Title>
            <Author>Author Nr 1</Author>
            <Recommendations positive="10" neutral="5" negative="1"/>
        </Book>
        <Book id="456">
            <Title>Book Nr 2</Title>
            <Author>Author Nr 2</Author>
            <Recommendations positive="0" neutral="5" negative="10"/>
        </Book>
    </Obj>
</XmlSerialisationWrapper>
"@

# ... can be used with these calls to transform the string into xml into pscustom into json into file ...
$xmlObj = [xml]$xmlInputString
$pscustom = $xmlObj | Convert-XMLtoPSObject
$json = $pscustom | ConvertTo-Json -Depth 20
$json | set-content "testjson.json" -Encoding UTF8

# ... and would result in an json like thise one
{
    "xml": "version=\"1.0\" encoding=\"utf-8\"",
    "XmlSerialisationWrapper": {
        "CurrentDate": "20201130",
        "Location": "Germany",
        "Messages": {
            "@errors": "0",
            "@warnings": "0",
            "@info": "1",
            "value": "All fine!"
        },
        "Obj": {
            "@type": "TablePersistentState",
            "Book": [
                {
                    "@id": "123",
                    "Title": "Book Nr 1",
                    "Author": "Author Nr 1",
                    "Recommendations": {
                        "@positive": "10",
                        "@neutral": "5",
                        "@negative": "1"
                    }
                },
                {
                    "@id": "456",
                    "Title": "Book Nr 2",
                    "Author": "Author Nr 2",
                    "Recommendations": {
                        "@positive": "0",
                        "@neutral": "5",
                        "@negative": "10"
                    }
                }
            ]
        }
    }
}


.INPUTS
  xml - Should be loaded as an xml object like [xml]$xmlString
  attributesPrefix - The prefix for the tag attributes; it is common to use @ but could also be something else...
.OUTPUTS
  After recursive calls you get a more flexible pscustom object back
.NOTES
  Published on 2020-11-30
#>
Function Convert-XMLtoPSObject {
  
  Param (
     [parameter(Mandatory=$true, ValueFromPipeline)] $XML
    ,[parameter(Mandatory=$false)][String] $attributesPrefix = "@"
  )
  
  begin {
  
    # Define the xml attributes that can be excluded
    $excludeAttributes = @("xsd", "xsi", "space", "xmlns", "nil")
  
  }
  
  process{
    $return = New-Object -TypeName PSCustomObject
    if ($xml.name -in @( "Axes" )) {
      
      #Write-Host "Hello WOrld"
    }

    # Handle attributes of xml tag
    $attributes = New-Object -TypeName PSCustomObject
    if ($XML.Attributes.Count -gt 0) {
      $XML.Attributes | ForEach {
        $a = $_
        $attName = $a.LocalName
        $attValue = $a.'#text'
        # Exclude attributes with xsd, xsi, space, xmlns, nil
        if ($attName -notin $excludeAttributes) {
          $return | Add-Member -MemberType NoteProperty -Name "$( $attributesPrefix )$( $attName )" -Value $attValue
        }
      }
    }

    # Loop through all child nodes and save it to the object or 
    # get into it recursively
    $xml.ChildNodes | where { $_.NodeType -notin @([System.Xml.XmlNodeType]::SignificantWhitespace)  } | foreach {
      
      $n = $_
      $name = $n.Get_name() # if there is an attribute with "name", then this function is the safer way to get the tag name

      #if ($name -in @( "Messages" )) {
      #  Write-Host "Hello WOrld"
      #}     
      
      # Decide if go recursively or use the current value
      if ($n.HasChildNodes) {
        if ($n.ChildNodes.Count -gt 1) {
          $value = [PSCustomObject]( Convert-XMLtoPSObject -XML $n -attributesPrefix $attributesPrefix )
        } else {
          if ($n.ChildNodes[0].NodeType -eq [System.Xml.XmlNodeType]::Text) {
            # Handle attributes of childrens tag
            if ($n.Attributes.Count -gt 0) {
              $value = New-Object -TypeName PSCustomObject
              $n.Attributes | ForEach {
                $a = $_
                $attName = $a.LocalName
                $attValue = $a.'#text'
                # Exclude attributes with xsd, xsi, space, xmlns, nil
                if ($attName -notin $excludeAttributes) {
                  $value | Add-Member -MemberType NoteProperty -Name "$( $attributesPrefix )$( $attName )" -Value $attValue
                }                
              }
              $v = $n.ChildNodes[0].Value
              if ($v -ne $null) {
                $value | Add-Member -MemberType NoteProperty -Name "value" -Value $v
              }
            } else {
              $value = $n.ChildNodes[0].Value
            }            
          } else {
            $value = [PSCustomObject]( Convert-XMLtoPSObject -XML $n -attributesPrefix $attributesPrefix )
          }
        }
      } else {
        # Handle attributes of childrens tag
        if ($n.Attributes.Count -gt 0) {
          $value = New-Object -TypeName PSCustomObject
          $n.Attributes | ForEach {
            $a = $_
            $attName = $a.LocalName
            $attValue = $a.'#text'
            # Exclude attributes with xsd, xsi, space, xmlns, nil
            if ($attName -notin $excludeAttributes) {
              $value | Add-Member -MemberType NoteProperty -Name "$( $attributesPrefix )$( $attName )" -Value $attValue
            }                
          }
          $v = $n.ChildNodes[0].Value
          if ($v -ne $null) {
            $value | Add-Member -MemberType NoteProperty -Name "value" -Value $v
          }
        } else {
          $value = $n.Value
        }            
      }

      # Decide how to save the data, a xml tag could be used multiple times
      if ( ( $return | Get-Member -MemberType NoteProperty | where { $_.Name -eq $name} ).Count -ge 1 ) {

        # An array exists... add to it
        if ( $return.$name -is [System.Collections.ArrayList] ) {
          $list = $return.$name
          $list.Add($value) | Out-Null # The out-null is very important for recursive functions and array creation, otherwise the array output will be sent to the function caller
          $return.$name = $list
        
        # No array exists... create one
        } elseif ( $return.$name -is [PSCustomObject] ) {
          $list = [System.Collections.ArrayList]@()
          $list.Add($return.$name) | Out-Null
          $list.Add($value) | Out-Null
          $return.$name = $list
        }
      
      # Otherwise just save that entry to the object
      } else {
        $return | Add-Member -MemberType NoteProperty -Name $name -Value $value
      }


    }
    if ($xml.name -in @( "Axes" )) {
      
      #Write-Host "Hello WOrld" #> $null
    }
    return $return
  }
}

