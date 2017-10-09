<#
.Synopsis
   Package DSC modules and mof configuration document and publish them on an enterprise DSC pull server in the required format.
.DESCRIPTION
   Uses Publish-DSCModulesAndMof function to package DSC modules into zip files with the version info. 
   Publishes the zip modules on "$env:ProgramFiles\WindowsPowerShell\DscService\Modules".
   Publishes all mof configuration documents that are present in the $Source folder on "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration"-
   Use $Force to overwrite the version of the module that exists in the PowerShell module path with the version from the $source folder.
   Use $ModuleNameList to specify the names of the modules to be published if the modules do not exist in $Source folder.
.EXAMPLE
    $ModuleList = @("xWebAdministration", "xPhp")
    Publish-DSCModuleAndMof -Source C:\LocalDepot -ModuleNameList $ModuleList
.EXAMPLE
    Publish-DSCModuleAndMof -Source C:\LocalDepot -Force
#>

# Tools to use to package DSC modules and mof configuration document and publish them on enterprise DSC pull server in the required format
function Publish-DscModuleAndMof {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Don''t use ShouldProcess in internal functions.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [UPClusterNode]$DscPullNode,
        # The folder that contains the configuration mof documents. Everything in this folder will be packaged and published.
        [Parameter(Mandatory = $true)]
        [string]$Path, 
        # Package and publish the modules listed in $ModuleNames based on PowerShell module path content.
        $Modules
    )

    function PackageModules {
        param (
            $Modules,
            [string]$Destination
        )

        # Move all required  modules from powershell module path to a temp folder and package them
        if ($Modules) {
            foreach ($module in $Modules) {
                if ($module -is [string]) {
                    $moduleName = $module
                    $moduleVersion = $null
                }
                else {
                    $moduleName = $module.ModuleName
                    $moduleVersion = $module.ModuleVersion
                }

                $availableModules = Get-Module -Name $moduleName -ListAvailable -Verbose:$false
                foreach ($availableModule in $availableModules) {
                    $availableModuleName = $availableModule.Name
                    $availableModuleVersion = $availableModule.Version.ToString()

                    $modulePath = Join-Path -Path $availableModule.ModuleBase -ChildPath '*'
                    $destinationFilePath = Join-Path -Path $Destination -ChildPath "$($availableModuleName)_$($availableModuleVersion).zip"

                    if (-not (Test-Path -Path $destinationFilePath -PathType Leaf)) {
                        Write-Log -Scope $MyInvocation -Message "Zipping module $availableModuleName ($availableModuleVersion)."
                        Compress-Archive -Path $modulePath -DestinationPath $destinationFilePath -Verbose:$false -Force 
                    }
                    else {
                        Write-Log -Scope $MyInvocation -Message "Module $availableModuleName ($availableModuleVersion) already zipped."
                    }
                }
            }
        }
        else {
            Write-Log -Scope $MyInvocation -Message "No additional modules are specified to be packaged." 
        }
    }

    function PublishModules {
        param (
            [string]$Path,
            [System.Management.Automation.Runspaces.PSSession]$Session
        )

        # TODO: find module-repository folder from web.config
        #       (Get-Website 'PSDSCPullServer').PhysicalPath
        #       appSetting:ModulePath
        $moduleRepository = "$env:ProgramFiles\WindowsPowerShell\DscService\Modules"
        [ScriptBlock]$scriptBlock = {
            param ($ModuleRepository)
            return (Get-Module ServerManager -ListAvailable) -and (Test-Path $ModuleRepository)
        }

        if ($Session) {
            $isDscPullServer = Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList $moduleRepository
        }
        else {
            $isDscPullServer = $scriptBlock.Invoke($moduleRepository)
        }

        if (-not $isDscPullServer) {
            Write-Warning "Copying module(s) to Pull server module repository skipped because the machine is not a server sku or Pull server endpoint is not deployed."
            return
        }

        Write-Log -Scope $MyInvocation -Message "Copying modules and checksums to [$moduleRepository]."
        if ($Session) {
            Copy-Item -Path "$Path\*.zip*" -Destination $moduleRepository -ToSession $Session -Force
        }
        else {
            Copy-Item -Path "$Path\*.zip*" -Destination $moduleRepository -Force
        }
    }

    function PublishMofDocuments {
       param (
            [string]$Path,
            [System.Management.Automation.Runspaces.PSSession]$Session
        )

        # TODO: find configuration-repository folder from web.config
        #       (Get-Website 'PSDSCPullServer').PhysicalPath
        #       appSetting:ConfigurationPath
        $mofRepository = "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration"
        [ScriptBlock]$scriptBlock = {
            param ($MofRepository)
            return (Get-Module ServerManager -ListAvailable) -and (Test-Path $MofRepository)
        }

        if ($Session) {
            $isDscPullServer = Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList $mofRepository
        }
        else {
            $isDscPullServer = $scriptBlock.Invoke($mofRepository)
        }

        if (-not $isDscPullServer) {
            Write-Warning "Copying configuration(s) to Pull server configuration repository skipped because the machine is not a server sku or Pull server endpoint is not deployed."
            return
        }

        Write-Log -Scope $MyInvocation -Message "Copying mofs and checksums to [$mofRepository]."
        if ($Session) {
            Copy-Item -Path "$Path\*.mof*" -Destination $mofRepository -ToSession $Session -Force
        }
        else {
            Copy-Item -Path "$Path\*.mof*" -Destination $mofRepository -Force
        }
    }

    Write-Log -Scope $MyInvocation -Message 'Start publishing...'

    # create checksums for MOF-files
    New-DSCCheckSum -Path $Path -Force

    # create cache folder for packages modules
    $modulesFolder = Join-Path -Path $Path -ChildPath 'Modules'
    New-Item -Path $modulesFolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

    # create cache folder for packages modules
    PackageModules -Modules $Modules -Destination $modulesFolder

    # create checksums for module-archives
    New-DSCCheckSum -Path $modulesFolder -Force

    Write-Log -Scope $MyInvocation -Message "Connecting to '$($DscPullNode.Name)'..."
    $session = New-UPClusterNodeSession -Node $DscPullNode
    if ($session) {
        Write-Log -Scope $MyInvocation -Message "Publishing configurations to '$($DscPullNode.Name)'..."
        PublishMofDocuments -Path $Path -Session $session
        if ($Modules) {
            Write-Log -Scope $MyInvocation -Message "Publishing modules to '$($DscPullNode.Name)'..."
            PublishModules -Path $modulesFolder -Session $session
        }
    }
    else {
        Write-Log -Scope $MyInvocation -Message "Failed to connect to '$($DscPullNode.Name)'..."
    }

    Write-Log -Scope $MyInvocation -Message 'End Deployment'
}
