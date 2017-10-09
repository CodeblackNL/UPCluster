function New-UPClusterServiceFabricConfiguration {
    [CmdletBinding(DefaultParameterSetName = 'Node')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'Name')]
        [string[]]$Name,
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'Node', ValueFromPipeline = $true)]
        [UPClusterNode[]]$Node,
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$TemplatePath,
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    if ($($PSCmdlet.ParameterSetName) -eq 'Name') {
        $nodes = Get-UPClusterNode -Name $Name
    }
    elseif ($Input) {
        $nodes = $Input
    }
    elseif ($($PSCmdlet.ParameterSetName) -eq 'Node' -and -not $Node) {
        if (-not $script:clusterConfiguration) {
            Write-Error "No current configuration."
            return
        }

        $Node = $script:clusterConfiguration.Nodes | Where-Object { $_.Roles | Where-Object { $_.Name -eq 'ServiceFabricNode' } }
    }

    $configurationContent = Get-Content -Path $TemplatePath -Raw | ConvertFrom-Json
    if (-not ($configurationContent | Get-Member -Name 'nodes')) {
        $configurationContent | Add-Member -MemberType NoteProperty -Name 'nodes' -Value @()
    }

    $defaultNoteTypeRef = $null
    if ($configurationContent.properties.nodeTypes -and @($configurationContent.properties.nodeTypes).Length -eq 1) {
        $defaultNoteTypeRef = $configurationContent.properties.nodeTypes[0]
    }
    $configurationContent.nodes = $Node | ForEach-Object {
        $nodeName = $_.AllProperties.nodeName
        if (-not $nodeName) {
            $nodeName = $_.Name
        }
        $nodeTypeRef = $_.AllProperties.nodeTypeRef
        if (-not $nodeTypeRef) {
            $nodeTypeRef = $defaultNoteTypeRef
        }
        elseif (-not ($configurationContent.properties.nodeTypes | Where-Object { $_.name -eq $nodeTypeRef })) {
            Write-Error "Unknown node-type '$nodeTypeRef' for node '$($_.Name)'."
        }

        if (-not $nodeTypeRef) {
            Write-Error "No node-type for node '$($_.Name)'."
        }
        if (-not $_.AllProperties.faultDomain) {
            Write-Error "No fault-domain for node '$($_.Name)'."
        }
        if (-not $_.AllProperties.upgradeDomain) {
            Write-Error "No upgrade-domain for node '$($_.Name)'."
        }
        
        New-Object -TypeName 'PSCustomObject' -Property @{
            iPAddress = $_.NetworkAdapters.StaticIPAddress | Select-Object -First 1
            nodeName = $_.AllProperties.nodeName
            nodeTypeRef = $nodeTypeRef
            faultDomain = $_.AllProperties.faultDomain
            upgradeDomain = $_.AllProperties.upgradeDomain
        }
    }

    $configurationText = (ConvertTo-Json -InputObject $configurationContent -Depth 9)

    if ($OutputPath) {
        $configurationText | Out-File -FilePath $OutputPath -Force:$Force -Confirm:$false -Encoding ASCII
    }
    else {
        Write-Output $configurationText
    }
}
