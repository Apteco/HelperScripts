$Parms = @{
  #Path = "C:\Test\New-ScriptFile.ps1"
  Verbose = $True
  Version = "0.9.001"
  Author = "florian.von.bracht@apteco.de"
  Description = "Apteco Customs - PowerShell logging script"
  CompanyName = "Apteco GmbH"
  Copyright = "2022 Apteco GmbH. All rights reserved."
  #ExternalModuleDependencies = "ff","bb"
  #RequiredScripts = "Start-WFContosoServer", "Stop-ContosoServerScript"
  #ExternalScriptDependencies = "Stop-ContosoServerScript"
  Tags = @("PSEdition_Desktop", "PSEdition_Core", "Windows","Apteco")
  ProjectUri = "https://github.com/Apteco/HelperScripts/tree/master/functions/Log"
  LicenseUri = "https://gist.github.com/gitfvb/58930387ee8677b5ccef93ffc115d836" #"http://www.apache.org/licenses/LICENSE-2.0"
  IconUri = "https://www.apteco.de/sites/default/files/favicon_3.ico"
  PassThru = $True
  ReleaseNotes = @(
    "Initial release of logging module through psgallery"
    #"Feature 1"
    #"Feature 2"
    #"Feature 3"
    #"Feature 4"
    #"Feature 5"
  )
  #RequiredModules = @("ModuleRequireLicenseAcceptance")
  #  "1",
  #  "2",
  #  "RequiredModule1",
  #  @{ModuleName="RequiredModule2";ModuleVersion="1.0"},
  #  @{ModuleName="RequiredModule3";RequiredVersion="2.0"},
  #  "ExternalModule1"
  }
New-ScriptFileInfo @Parms