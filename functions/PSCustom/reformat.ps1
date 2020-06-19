
Function Format-KeyValue {

<#

Good hints pipeline input

Example call:
$globalAttributes | select -first 2 | select id,  geschlecht, anrede, city, firstname | Format-KeyValue -idPropertyName "id"
or
Format-KeyValue -psobject ( $globalAttributes | select -first 2 | select id,  geschlecht, anrede, city, firstname  ) -idPropertyName "id"

Having this as in input

id geschlecht anrede city   firstname
-- ---------- ------ ----   ---------
4  male       Herr   Berlin Gernot
5  male       Herr   Berlin Sascha

it will reformat it to

Id Name       Value 
-- ----       -----
4  id         4
4  geschlecht male
4  anrede     Herr  
4  city       Berlin
4  firstname  Gernot
5  id         5
5  geschlecht male
5  anrede     Herr
5  city       Berlin
5  firstname  Sascha

#>

    param(
         [Parameter(ValueFromPipeline,Mandatory=$true)][PSCustomObject[]] $psobject
        ,[Parameter(Mandatory=$true)][String] $idPropertyName 
        ,[Parameter(Mandatory=$false)][Switch] $removeEmptyValues = $false
    )

    BEGIN {}
    PROCESS {
        $psobject | foreach {
            $id = $_.$idPropertyName 
            $_.psobject.properties | foreach {                
                if ( $_.Value.length -gt 0 -or $removeEmptyValues -ne $true ) {                     
                    [PSCustomObject]@{
                        "Id" = $id
                        "Name" = $_.Name 
                        "Value" = $_.Value  
                    }
                }
            } 
        }
    }
    END {}

}


Function Format-Array {

<#

example calls
Format-Array -psobject ( $contacts | where { $_.tags.count -gt 0 }  | select -Unique id, tags ) -idPropertyName "Id" -arrPropertyName "tags"
$contacts | where { $_.tags.count -gt 0 }  | select -Unique id, tags | Format-Array -idPropertyName "Id" -arrPropertyName "tags"


if you have input like 

id   tags
--   ----
666  {Drupal-Site.Apteco, Drupal-Role.Authenticated_user, Drupal-Special.Contact, Drupal-Role.Content_Writer}  
2350 {Drupal-Site.Apteco, Drupal-Role.Authenticated_user, Drupal-Special.Contact, Drupal-Role.Content_Writer}

this function solves it to

Id   Tag
--   ---
666  Drupal-Site.Apteco
666  Drupal-Role.Authenticated_user
666  Drupal-Special.Contact
666  Drupal-Role.Content_Writer
2350 Drupal-Site.Apteco
2350 Drupal-Role.Authenticated_user
2350 Drupal-Special.Contact
2350 Drupal-Role.Content_Writer

#>

    param(
         [Parameter(ValueFromPipeline,Mandatory=$true)][PSCustomObject[]] $psobject
        ,[Parameter(Mandatory=$true)][String] $idPropertyName
        ,[Parameter(Mandatory=$true)][String] $arrPropertyName
    )

    BEGIN {}
    PROCESS {
        $psobject | foreach {
            $id = $_.id
            $_.$arrPropertyName | foreach {
                [pscustomobject]@{
                    "Id" = $id
                    $arrPropertyName = $_ 
                }
            } 
        }
    }
    END {}
    
}
