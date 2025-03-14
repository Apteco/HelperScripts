
#-----------------------------------------------
# LOAD SCRIPTS AND MODULES
#-----------------------------------------------

"Loading scrtipts and modules..."

$psScripts | ForEach {
    $scriptName = $_
    try {
        "Loading scripts"
        "    $( $scriptName )"
        Get-Command -Name $scriptName | % { . $_.Source }
    } catch {
        Write-Error -Message "Dependency '$( $scriptName )' not present"
    }
}

# [ ] TODO possibly check if all dependencies are installed

$psModules | ForEach {
    # [ ] TODO implement this!
}


#-----------------------------------------------
# LOAD FUNCTIONS
#-----------------------------------------------

"Loading functions..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}


#-----------------------------------------------
# LOAD KERNEL32 FOR ALTERNATIVE DLL LOADING
#-----------------------------------------------

Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    
    public static class Kernel32 {
        [DllImport("kernel32")]
        public static extern IntPtr LoadLibrary(string lpFileName);
    }    
"@


#-----------------------------------------------
# LOAD LIB FOLDER (DLLs AND ASSEMBLIES)
#-----------------------------------------------

"Loading libs..."

# TODO [ ] Define a priority later for .net versions, but use fixed ones at the moment
# These lists will be checked in the defined order
$dotnetVersions = @("net6.0","net6.0-windows","net5.0","net5.0-windows","netcore50","netstandard2.1","netstandard2.0","netstandard1.5","netstandard1.3","netstandard1.1","netstandard1.0")
$targetFolders = @("ref","lib")
$runtimes = @("win-x64","win-x86","win10","win7","win")

Get-ChildItem -Path ".\lib" -Directory | ForEach {

    $package = $_
    #"Checking package $( $package.BaseName )"
    $packageLoaded = 0
	$loadError = 0

    # Check the ref folder
    If ( ( Test-Path -Path "$( $package.FullName )/ref" ) -eq $true ) {
        $subfolder = "ref"
        $dotnetVersions | ForEach {
            $dotnetVersion = $_
		    #"Checking $( $dotnetVersion )"
            $dotnetFolder = "$( $package.FullName )/$( $subfolder )/$( $dotnetVersion )"
            If ( (Test-Path -Path $dotnetFolder)  -eq $true -and $packageLoaded -eq 0) {
                Get-ChildItem -Path $dotnetFolder -Filter "*.dll" | ForEach {
                    $f = $_
			        #"Loading $( $f.FullName )"                    
                    try {
                        [void][Reflection.Assembly]::LoadFile($f.FullName)
                        $packageLoaded = 1
                        #"Loaded $( $dotnetFolder )"
                    } catch {
                        $loadError = 1
                    }
                }                
            }
        }
    }
    
    # Check the lib folder
    if ( ( Test-Path -Path "$( $package.FullName )/lib" ) -eq $true -and $packageLoaded -eq 0) {
        $subfolder = "lib"
        $dotnetVersions | ForEach {
            $dotnetVersion = $_
		    #"Checking $( $dotnetVersion )"
            $dotnetFolder = "$( $package.FullName )/$( $subfolder )/$( $dotnetVersion )"
            If ( (Test-Path -Path $dotnetFolder)  -eq $true -and $packageLoaded -eq 0) {
                Get-ChildItem -Path $dotnetFolder -Filter "*.dll" | ForEach {
                    $f = $_
			        #"Loading $( $f.FullName )"                    
                    try {
                        [void][Reflection.Assembly]::LoadFile($f.FullName)
                        $packageLoaded = 1
                        #"Loaded $( $dotnetFolder )"
                    } catch {
                        $loadError = 1
                    }
                }
                
                
            }
        }
    }
    
    # Output the current status
	If ($packageLoaded -eq 1) {
	    "OK lib/ref $( $f.fullname )"
    } elseif ($loadError -eq 1) {
	    "ERROR lib/ref $( $f.fullname )"
    } else {
        #"Not loaded lib/ref $( $package.fullname )"
    }
    
    # Check the runtimes folder
    $runtimeLoaded = 0
    $runtimeLoadError = 0
    #$useKernel32 = 0
    if ( ( Test-Path -Path "$( $package.FullName )/runtimes" ) -eq $true -and $runtimeLoaded -eq 0) {
        $subfolder = "runtimes"
        $runtimes | ForEach {
            $runtime = $_
		    #"Checking $( $dotnetVersion )"
            $runtimeFolder = "$( $package.FullName )/$( $subfolder )/$( $runtime )"
            If ( (Test-Path -Path $runtimeFolder)  -eq $true -and $runtimeLoaded -eq 0) {
                Get-ChildItem -Path $runtimeFolder -Filter "*.dll" -Recurse | ForEach {
                    $f = $_
			        #"Loading $( $f.FullName )"                    
                    try {
                        [void][Reflection.Assembly]::LoadFile($f.FullName)
                        $runtimeLoaded = 1
                        #"Loaded $( $dotnetFolder )"
                    } catch [System.BadImageFormatException] {
                        # Try it one more time with LoadLibrary through Kernel
                        [Kernel32]::LoadLibrary($f.FullName)
                        $runtimeLoaded = 1
                        #$useKernel32 = 1
                    }  catch {
                        $runtimeLoadError = 1
                    }
                }
                
                
            }
        }
    }

    If ($runtimeLoaded -eq 1) {
	    "OK runtime $( $f.fullname )"
    } elseif ($runtimeLoadError -eq 1) {
	    "ERROR runtime $( $f.fullname )"
    } else {
    #    "Not loaded runtime for $( $package.fullname )"
    }

    If ( $runtimeLoaded -eq 0 -and $packageLoaded -eq 0 ) {
        "NO $( $package.fullname )"
    } 

    #} else {
    #    #"No ref or lib folder"
    #}

}





<#
If ( $configMode -and -not $settings) {

    # Don't load yet, when in config mode and settings object not yet available

} else {
    
    # Load all exe files in subfolder
    $libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
    $libExecutables | ForEach {
        "... $( $_.FullName )"
    
    }

    # Load dll files in subfolder
    $libDlls = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
    $libDlls | ForEach {
        "Loading $( $_.FullName )"
        [Reflection.Assembly]::LoadFile($_.FullName) 
    }

}
#>

#Add-Type -AssemblyName System.Security
