
function Get-UPClusterNode {
    param (
        [Parameter(Mandatory = $false)]
        [string[]]$Name
    )

    if ($script:clusterConfiguration -and $script:clusterConfiguration.Nodes) {
        foreach ($node in $script:clusterConfiguration.Nodes) {
            if (-not $Name -or @($Name | Where-Object { $node.Name -like $_ }).Length -gt 0) {
                Write-Output $node
            }
        }
    }
}
