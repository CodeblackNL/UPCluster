function Get-UPClusterConfiguration {

    if (-not $script:clusterConfiguration) {
        $configurationFilePath = Join-Path -Path (Get-Location) -ChildPath 'cluster.json'
        if (Test-Path -Path $configurationFilePath -PathType Leaf) {
            Import-UPClusterConfiguration -Path $configurationFilePath
        }
    }

    if (-not $script:clusterConfiguration) {
        $configurationFilePath = Join-Path -Path ($env:ALLUSERSPROFILE) -ChildPath 'UPCluster\cluster.json'
        if (Test-Path -Path $configurationFilePath -PathType Leaf) {
            Import-UPClusterConfiguration -Path $configurationFilePath
        }
    }

    return $script:clusterConfiguration
}
