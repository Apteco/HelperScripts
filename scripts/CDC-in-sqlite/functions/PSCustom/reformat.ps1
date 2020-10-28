
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

You can also define multiple IDs with a call like this

$t | Format-KeyValue -idPropertyName id,group_id -removeEmptyValues

to get multiple ids as columns like this

id   group_id Name              Value                                                               
--   -------- ----              -----                                                               
666  1112144  communication_key be66add3-d60a-ea11-a406-004e019d9caa                                
666  1112144  discount          20%                                                                 
666  1112144  first_name        James                                                               
666  1112144  urn               1                                                                   
2345 1112144  communication_key b666add3-d60a-ea11-a406-004e019d9caa                                
2345 1112144  discount          20%                                                                 
2345 1112144  first_name        Stuart                                                              
2345 1112144  urn               79       

#>

    param(
         [Parameter(ValueFromPipeline,Mandatory=$true)][PSCustomObject[]] $psobject
        ,[Parameter(Mandatory=$true)][String[]] $idPropertyName 
        ,[Parameter(Mandatory=$false)][Switch] $removeEmptyValues = $false
    )

    BEGIN {}
    PROCESS {
        $idNames = $idPropertyName -split ","
        $psobject | foreach {
            #$ids = $idNames | ForEach {}
            #$id = $_.$idPropertyName 
            $curObject = $_
            $_.psobject.properties | foreach {                
                if ( ( $_.Value.length -gt 0 -or $removeEmptyValues -ne $true ) -and $idNames -notcontains $_.Name ) {                                         
                    $newObj = New-Object PSCustomObject
                    $idNames | ForEach {                   
                        $newObj | Add-Member -MemberType NoteProperty -Name $_ -Value $curObject.$_
                    }
                    $newObj | Add-Member -MemberType NoteProperty -Name "Name" -Value $_.Name
                    $newObj | Add-Member -MemberType NoteProperty -Name "Value" -Value $_.Value
                    $newObj
                    <#
                    [PSCustomObject]@{
                        "Id" = $id
                        "Name" = $_.Name 
                        "Value" = $_.Value  
                    }
                    #>

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
