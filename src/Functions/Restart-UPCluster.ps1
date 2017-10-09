
function Restart-UPCluster {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$NoWait
    )

    $nodes = Test-UPClusterNode -Node ($script:clusterConfiguration.Nodes) -PassThru
    if ($nodes) {
        $dcNode = $nodes | Where-Object { $_.Roles | Where-Object { $_.Name -eq 'DomainController' } }
        if ($dcNode) {
            $nodes = $nodes | Where-Object { $_.Name -ne $dcNode.Name }
        }

        try {
            Restart-UPClusterNode -Node $nodes -Wait:(!($NoWait.IsPresent))
        }
        catch {
            $error = $_
        }
        if ($dcNode) {
            Restart-UPClusterNode -Node $nodes -Wait:(!($NoWait.IsPresent))
        }
        if ($error) {
            throw $error
        }
    }
}
