# Reference: https://powersnippets.com/convertto-datatable/

Function ConvertTo-DataTable {									# https://powersnippets.com/convertto-pson/
	[CmdletBinding()]Param(										# Version 01.00.01, by iRon
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [PSObject[]]$Object, [HashTable]$ColumnType = @{}
	)
	$TypeCast = @{
		Guid     = 'Guid', 'String'
		DateTime = 'DateTime', 'String'
		Byte     = 'Byte', 'Char', 'Int16', 'Int32', 'Int64', 'UInt16', 'UInt32', 'UInt64', 'Decimal', 'Single', 'Double', 'String', 'Boolean'
		SByte    = 'SByte', 'Int16', 'Int32', 'Int64', 'Decimal', 'Single', 'Double', 'String', 'Boolean'
		Char     = 'Char', 'Int32', 'Int64', 'UInt16', 'UInt32', 'UInt64', 'String'
		TimeSpan = 'TimeSpan', 'String'
		Int16    = 'Int16', 'Int32', 'Int64', 'Decimal', 'Single', 'Double', 'String', 'Boolean'
		Int32    = 'Int32', 'Int64', 'Decimal', 'Single', 'Double', 'String', 'TimeSpan', 'Boolean'
		Int64    = 'Int64', 'Decimal', 'Single', 'Double', 'String', 'TimeSpan', 'Boolean'
		UInt16   = 'Int32', 'Int64', 'UInt16', 'UInt32', 'UInt64', 'Decimal', 'Single', 'Double', 'Char', 'String', 'Boolean'
		UInt32   = 'Int64', 'UInt32', 'UInt64', 'Decimal', 'Single', 'Double', 'String', 'Boolean'
		UInt64   = 'UInt64', 'Decimal', 'Single', 'Double', 'String', 'Boolean'
		Decimal  = 'Decimal', 'Single', 'Double', 'String', 'Boolean'
		Single   = 'Single', 'Double', 'String', 'Boolean'
		Double   = 'Double', 'Single', 'String', 'Boolean'
		String   = 'String'
		Boolean  = 'Boolean', 'Byte', 'SByte', 'Int16', 'Int32', 'Int64', 'UInt16', 'UInt32', 'UInt64', 'Decimal', 'Single', 'Double', 'String'
	}
	$PipeLine = $Input | ForEach {$_}; If ($PipeLine) {$Object = $PipeLine}
	$DataTable = New-Object Data.DataTable
	$First = $Object | Select-Object -First 1
	$Properties = $First | Get-Member -Type Property; If (!$Properties) {$Properties = $First | Get-Member -Type NoteProperty}
	$Names = ForEach ($Property in $Properties) {$First.PSObject.Properties | Where {$_.Name -eq $Property.Name -and $_.IsGettable} | Select -Expand "Name"}
	ForEach($Name in $Names) {
		If ($ColumnType.ContainsKey($Name)) {$Type = $ColumnType.$Name} Else {
			$Types = $Object | Where-Object {$Null -ne $_.$Name} | ForEach {$_.$Name.GetType().Name} | Where-Object {$TypeCast.ContainsKey($_)} | Select-Object -Unique
			$Type = If ($Types.Count -gt 1) {
				$Cast = $TypeCast[$Types[0]]; ForEach ($Type in ($Types | Select-Object -Skip 1)) {$Cast = $Cast | Where-Object {$TypeCast[$Type] -Contains $_}}
				If ($Cast) {@($Cast)[0]} Else {'String'}
			} ElseIf ($Types) {$Types} Else {'String'}
		}
		$DataColumn = New-Object Data.DataColumn
		$DataColumn.ColumnName = $Name
		$DataColumn.DataType = [System.Type]::GetType("System.$Type")
		$DataTable.Columns.Add($DataColumn)
	}
	ForEach($RowObject in $Object) {
		$DataRow = $DataTable.NewRow()
		ForEach($Name in $Names) {$DataRow.Item($Name) = If ($Null -ne $RowObject.$Name) {$RowObject.$Name} Else {[DBNull]::Value}}
		$DataTable.Rows.Add($DataRow)
	}
	Write-Output (,($DataTable))
} Set-Alias ctdt ConvertTo-DataTable -Description "Converts a PowerShell object list to a DataTable"