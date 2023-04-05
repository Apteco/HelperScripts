<#
Source originally from: https://gallery.technet.microsoft.com/scriptcenter/Export-Hashtable-to-xml-in-122fda31/view/Discussions#content

Added support for namespaces in the root node
#>

Function Out-HashTableToXml {

	[cmdletbinding(SupportsShouldProcess=$false)]
	
	Param(
	    [ValidateNotNullOrEmpty()]
	    [Parameter(Mandatory=$true)][System.String]$Root,
	    [Parameter(ValueFromPipeline = $true, Position = 0)][System.Collections.Hashtable]$InputObject,
	    [Parameter(Mandatory=$false)][ValidateScript({ Test-Path $_ -IsValid })][System.String]$Path = "",
        [Parameter(Mandatory=$false)][System.Collections.Hashtable]$namespaces
	)
	
	Begin {
	    $ScriptBlock = {
	        Param($Elem, $Root)
	        if ($Elem.Value -is [Array]) {
	            $Elem.Value | Foreach-Object {
	                #$ScriptBlock.Invoke(@(@{$($Elem.Key)=$_}, $Root)) # <- FAILS
					$p = [System.Collections.DictionaryEntry]@{"Key"=$Elem.Key;"Value"=$_}
	                $ScriptBlock.Invoke($p, $Root)
	            }
	        } elseif($Elem.Value -is [System.Collections.Hashtable]) {
	            $RootNode = $Root.AppendChild($Doc.CreateNode([System.Xml.XmlNodeType]::Element,$Elem.Key,$Null))
	            $Elem.Value.GetEnumerator() | ForEach-Object {
	                $Scriptblock.Invoke( @($_, $RootNode) )
	            }
	        } else {
	            $Element = $Doc.CreateElement($Elem.Key)
	            $p = if($Elem.Value -is [Array]) {
	                $Elem.Value -join ','
	            } else {
	                $Elem.Value | Out-String
	            }
				if ($p -match '\S') { $Element.InnerText = $p.Trim() }
				$Root.AppendChild($Element) | Out-Null
	        }
	    } 
	}
	
	Process {
        
        # Create empty xml
        $Doc = New-Object System.XML.XMLDocument
        
        # Add namespaces
        $nsm = New-Object System.Xml.XmlNamespaceManager($Doc.NameTable)
        $namespaces.Keys | ForEach {
            $prefix = $_
            $uri = $namespaces[$prefix]
            $nsm.AddNamespace($prefix,$uri)
        }
        
        # Create root namespace, if it is defined
        if ( $Root -like "*:*" ) {
            $rootPrefix = ( $Root -split ":" )[0]
        }
        if ( $namespaces.Count -gt 0 ) {
            $namespace = $nsm.LookupNamespace($rootPrefix)
        } else {
            $namespace = $null
        }

        # Create root node
        $rootNode = $Doc.CreateNode([System.Xml.XmlNodeType]::Element,$Root,$namespace)
        $Doc.AppendChild($rootNode) 
             
        # Add XML Declaration
        $XD = $Doc.CreateXmlDeclaration("1.0","UTF-8","yes")
		$Doc.InsertBefore($XD, $Doc.DocumentElement) | Out-Null
	    
        # Add subnodes recursively
        $InputObject.GetEnumerator() | ForEach-Object {
			$scriptblock.Invoke( @($_, $Doc.DocumentElement) )
	    }
        
        # Output of xml, if path is provided
	    if ( $Path -ne "" ) {
            $Doc.Save($Path)
        }

        # Return xml as string anyway
        return $Doc.OuterXml

	}
	
}