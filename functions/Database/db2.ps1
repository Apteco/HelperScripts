Function db2-Load-Assemblies {
    $db2AssemblyFile = "C:\Program Files\Apteco\FastStats Designer\IBM.Data.DB2.dll"
    [Reflection.Assembly]::LoadFile($db2AssemblyFile)
}

Function db2-Open-Connection {
    
}

Function db2-Load-DataTable {
    
}