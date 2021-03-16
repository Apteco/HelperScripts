
Function Get-FsTableHierarchy {

    param(
        [parameter(Mandatory=$true, ValueFromPipeline)] $tables
    )

    begin {
        $hierarchy = [PSCustomObject]@{}
        $parentColumn = "parentTable"
    }

    process {

        # Add all elements with no parenttable now
        $key = ( $tables | where { $_.$parentColumn -eq "" } ).name

        $value = [PSCustomObject]@{} #@()
        $tables | where { $_.$parentColumn -eq $key } | ForEach {
            $table = $_
            $tableName = $table.name

            # Add all entries without child tables straight away
            if ( $table.hasChildTables -eq $false ) {
                $value | Add-Member -MemberType NoteProperty -Name $tableName -Value $null <# += [PSCustomObject]@{
                    $table.name = $null
                }#>
            # All tables with child tables go into recursive calculation
            } else {
                # Create the current table with an empty "parentTable" and all tables without empty parentTable and where parentTable -ne $key
                $recursiveList = @()
                $recursiveList += $table | Select * -ExcludeProperty parentTable | select *, @{name=$parentColumn;expression={ "" }}
                $recursiveList += $tables | where { $_.$parentColumn -notin @($key,"")}
                $childTables = Get-FsTableHierarchy -tables $recursiveList
                $value | Add-Member -MemberType NoteProperty -name $tableName -value $childTables.$tableName
            }
            
        }

        $hierarchy | Add-Member -MemberType NoteProperty -Name $key -Value $value

    }

    end {
        # return
        $hierarchy
        #$value
    }
}

# Root table
$h = Get-FsTableHierarchy -tables $tables.list
$h | ConvertTo-Json -Depth 20


