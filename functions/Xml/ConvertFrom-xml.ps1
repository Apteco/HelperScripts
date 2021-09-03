<#

https://gist.github.com/elvarb/a3e2f7b6ed5e56ae38c1c7e35d7016d9

#>

# From https://stackoverflow.com/questions/42636510/convert-multiple-xmls-to-json-list
# Use 
#   [xml]$var = Get-Content file.xml
# Convert to JSON with 
#   $var | ConvertFrom-XML | ConvertTo-JSON -Depth 3

# Helper function that converts a *simple* XML document to a nested hashtable
# with ordered keys.
function ConvertFrom-Xml {
  param([parameter(Mandatory, ValueFromPipeline)] [System.Xml.XmlNode] $node)
  process {
    if ($node.DocumentElement) { $node = $node.DocumentElement }
    $oht = [ordered] @{}
    $name = $node.Name
    if ($node.FirstChild -is [system.xml.xmltext]) {
      $oht.$name = $node.FirstChild.InnerText
    } else {
      $oht.$name = New-Object System.Collections.ArrayList 
      foreach ($child in $node.ChildNodes) {
        $null = $oht.$name.Add((ConvertFrom-Xml $child))
      }
    }
    $oht
  }
}

#[xml[]] (Get-Content -Raw file[12].xml) | ConvertFrom-Xml | ConvertTo-Json -Depth 3

# -Depth might need tweaking depending on the depth of the XML file