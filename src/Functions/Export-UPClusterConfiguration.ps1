function Export-UPClusterConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    if (-not $script:clusterConfiguration) {
        Write-Error "No current configuration; nothing to export."
    }

    if (Test-Path -Path $OutputPath -PathType Container) {
        # OutputPath is an existing folder; add default file-name
        $outputFilePath = Join-Path -Path $OutputPath -ChildPath $script:defaultConfigurationFileName
    }
    elseif (Test-Path -Path $OutputPath -PathType Leaf) {
        # OutputPath is an existing file; only allowed with Force
        if (-not $Force.IsPresent) {
            Write-Error "File '$OutputPath' already exists; use Force to overwrite."
        }

        $outputFilePath = $OutputPath
    }
    elseif (!![system.io.path]::GetExtension($OutputPath)) {
        # OutputPath does not exist, but seems to have an extension; assume it's a file-path
        $outputFilePath = $OutputPath
    }
    else {
        # OutputPath does not exist, assume it's a folder-path; add default file-name
        $outputFilePath = Join-Path -Path $OutputPath -ChildPath $script:defaultConfigurationFileName
    }

    $exportContent = (ConvertTo-Json -InputObject $script:clusterConfiguration.Export() -Depth 9)

    $outputFolderPath = Split-Path -Path $outputFilePath -Parent
    if (-not (Test-Path -Path $outputFolderPath -PathType Container)) {
        New-Item -Path $outputFolderPath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    }

    $exportContent | Out-File -FilePath $outputFilePath -Force -Confirm:$false -Encoding ASCII
}
