
function Update-UPClusterNode {
    [CmdletBinding(DefaultParameterSetName = 'Node_DscPullNode')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'NodeName_DscPullNode')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'NodeName_DscPullNodeName')]
        [string[]]$Name,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Node_DscPullNode', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Node_DscPullNodeName', ValueFromPipeline = $true)]
        [UPClusterNode[]]$Node,
        [Parameter(Mandatory = $false, ParameterSetName = 'NodeName_DscPullNode')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Node_DscPullNode')]
        [UPClusterNode]$DscPullNode,
        [Parameter(Mandatory = $false, ParameterSetName = 'NodeName_DscPullNodeName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Node_DscPullNodeName')]
        [string]$DscPullNodeName,
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        [Parameter(Mandatory = $false)]
        [switch]$Publish,
        [Parameter(Mandatory = $false)]
        [switch]$Update,
        [Parameter(Mandatory = $false)]
        [switch]$Wait
    )

    if (-not $Publish.IsPresent -and -not $Update.IsPresent) {
        $Publish = $true
        $Update = $true
    }

    if ($($PSCmdlet.ParameterSetName) -in 'NodeName_DscPullNode', 'NodeName_DscPullNodeName') {
        $nodes = Get-UPClusterNode -Name $Name
    }
    elseif ($Input) {
        $nodes = $Input
    }
    else {
        $nodes = $Node
    }

    if ($($PSCmdlet.ParameterSetName) -in 'NodeName_DscPullNodeName', 'Node_DscPullNodeName') {
        $dscPullNodes = Get-UPClusterNode -Name $DscPullNodeName
        if ($dscPullNodes -and @($dscPullNodes).Length -eq 1) {
            $DscPullNode = $dscPullNodes[0]
        }
        else {
            throw "DscPullNodeName '$DscPullNodeName' does not result in a single node."
        }
    }

    if (-not $DscPullNode) {
        $DscPullNode = $nodes | Where-Object { $_.Roles | Where-Object { $_.Name -eq 'DscPullServer' } }
    }
    if (-not $DscPullNode) {
        throw 'No DscPullNode provided and no node provided with role DscPullServer.'
    }

    if ($nodes) {
        if ($Publish.IsPresent -and $script:clusterConfiguration.ConfigurationFilePath -and $script:clusterConfiguration.ConfigurationName) {
            if (-not $OutputPath) {
                $OutputPath = Join-Path -Path (Join-Path -Path $env:windir -ChildPath 'Temp') -ChildPath 'UPClusterConfiguration'
            }
            if (-not (Test-Path -Path $OutputPath -PathType Container)) {
                New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
            }
            else {
                Get-ChildItem -Path $OutputPath -Filter '*.mof*' | Remove-Item -Force
            }

            Write-Log -Scope $MyInvocation -Message "Updating DSC-configuration..."
            $configurationFilePath = $script:clusterConfiguration.ConfigurationFilePath
            if ($configurationFilePath.StartsWith('.')) {
                $configurationFilePath = [System.IO.Path]::GetFullPath((Join-Path -Path (Split-Path -Path $script:clusterConfiguration.Path -Parent) -ChildPath $configurationFilePath))
            }

            if (Test-Path -Path $configurationFilePath -PathType Leaf) {
                Write-Log -Scope $MyInvocation -Message "Loading configuration '$configurationFilePath'..."
                . $configurationFilePath

                Write-Log -Scope $MyInvocation -Message "Preparing configuration-data..."
                $configurationData = @{
                    AllNodes = @(
                        @{
                            NodeName = '*'
                            PSDscAllowPlainTextPassword = $true
                            PSDscAllowDomainUser = $true
                        }
                    )
                }
                $nodes | ForEach-Object {
                    $n = $_.ToHashtable()
                    $n.NodeName = $_.Name
                    $configurationData.AllNodes += $n
                }

                Write-Log -Scope $MyInvocation -Message "Generating MOF-files..."
                . $script:clusterConfiguration.ConfigurationName -ConfigurationData $configurationData -OutputPath $OutputPath | Out-Null

                Write-Log -Scope $MyInvocation -Message "Determining modules..."
                $content = get-content -Path $configurationFilePath -Encoding Ascii
                $modules = @()
                $content | ForEach-Object {
                    $moduleName = $null
                    $moduleVersion = $null
                    if ($_ -match 'Import[–-]DscResource') {
                        if ($_ -match '[–-]ModuleName [''"]?(?<ModuleName>\w*)[''"]?') {
                            $moduleName = $Matches.ModuleName
                        }
                        if ($moduleName) {
                            if ($_ -match '[–-]ModuleVersion [''"]?(?<ModuleVersion>[\d\.]*)[''"]?') {
                                $moduleVersion = $Matches.ModuleVersion
                            }

                            if (-not ($modules | Where-Object { $_.ModuleName -eq $moduleName -and $_.ModuleVersion -eq $moduleVersion })) {
                                $modules += @{
                                    ModuleName = $moduleName
                                    ModuleVersion = $moduleVersion
                                }
                            }
                        }
                    }
                }
        
                Write-Log -Scope $MyInvocation -Message "Publish MOF-files & modules..."
                Publish-DscModuleAndMof -DscPullNode $DscPullNode -Path $OutputPath -Modules $modules
            }
        }

        if ($Update.IsPresent) {
            Write-Log -Scope $MyInvocation -Message "Updating configuration on nodes..."
            #$updateNodes = Test-UPClusterNode -Node ($nodes | Where-Object { $_.Name -ne $DscPullNode.Name}) -PassThru | Where-Object { $_ }
            $updateNodes = Test-UPClusterNode -Node $nodes -PassThru | Where-Object { $_ }
            if (-not $updateNodes) {
                Write-Log -Scope $MyInvocation -Message "No nodes to update."
            }
            else {
                $nodeConnections = $updateNodes | ForEach-Object {
                    Get-UPClusterNodeConnectionInfo -Node $_
                }

                ForEach-Parallel -Items $nodeConnections -ArgumentList ($Wait.IsPresent) -ScriptBlock {
                    param ([bool]$Wait)

                    Update-DscConfiguration -ComputerName $_.ComputerName -Credential $_.Credential -Wait:$Wait | Out-Null
                }
            }
        }
    }
}
