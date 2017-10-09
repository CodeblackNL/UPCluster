
function Connect-UPClusterServiceFabric {
    [CmdletBinding(DefaultParameterSetName = 'Node')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'NodeName')]
        [string]$NodeName,
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'Node', ValueFromPipeline = $true)]
        [UPClusterNode]$Node,
        [Parameter(Mandatory = $false)]
        [int]$Port = 19000
    )

    if ($($PSCmdlet.ParameterSetName) -eq 'NodeName') {
        $nodes = Get-UPClusterNode -Name $NodeName
        if ($nodes -and @($nodes).Length -eq 1) {
            $Node = $nodes[0]
        }
        else {
            throw "Name '$Name' does not result in a single node."
        }
    }

    if ($Node) {
        if ($Node.Roles | Where-Object { $_.Name -eq 'ServiceFabricNode' }) {
            $serviceFabricNodes = @($Node)
        }
        else {
            throw "Node '$($Node.Name)' is not a Service Fabric node."
        }
    }
    else {
        if (-not $script:clusterConfiguration) {
            Write-Error "No current configuration."
        }

        $serviceFabricNodes = $script:clusterConfiguration.Nodes | Where-Object { $_.Roles | Where-Object { $_.Name -eq 'ServiceFabricNode' } } | Sort-Object Name
        if (-not $serviceFabricNodes) {
            throw "Current cluster does not contain any Service Fabric nodes."
        }

        #$serviceFabricNodes = Test-UPClusterNode -Node $serviceFabricNodes -PassThru
        #if (-not $serviceFabricNodes) {
        #    throw "Current cluster does not contain any active Service Fabric nodes."
        #}
    }

    if ($serviceFabricNodes) {
        foreach ($serviceFabricNode in $serviceFabricNodes) {
            $nodeConnection = Get-UPClusterNodeConnectionInfo -Node $serviceFabricNode
            $connectionEndpoint = "$($nodeConnection.ComputerName):$($Port)"

            # TODO: pass credential if needed
            $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $connectionEndpoint -ErrorAction SilentlyContinue
            if ($connection) {
                Write-Output $connection
                break
            }
        }
    }
}
