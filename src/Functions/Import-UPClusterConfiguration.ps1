function Import-UPClusterConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Any })]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    $Path = (Resolve-Path -Path $Path).Path

    if (Test-Path -Path $Path -PathType Container) {
        Write-Verbose "Path '$Path' is folder, assuming filename is missing; appending default: '$($script:defaultConfigurationFileName)'."
        $Path = Join-Path -Path $Path -ChildPath $script:defaultConfigurationFileName
    }

    if (Test-Path -Path $Path -PathType Leaf) {
        Write-Verbose "file '$Path' found"
        $configurationContent = Get-Content -Path $Path -Raw

        $tokensFilePath = [System.IO.Path]::GetFullPath((Join-Path -Path (Split-Path -Path $Path -Parent) -ChildPath 'tokens.json'))
        if (Test-Path -Path $tokensFilePath -PathType Leaf) {
            Write-Verbose "Processing token-file '$tokensFilePath'."
            $tokens = Get-Content -Path $tokensFilePath -Raw | ConvertFrom-Json | Convert-PSObjectToHashtable
            foreach ($key in $tokens.Keys) {
                try {
                    $configurationContent = $configurationContent.Replace("{$key}", ($tokens.$key))
                }
                catch {
                    Write-Warning -Message "Error replacing token '$key'."
                }
            }
        }

        $clusterConfiguration = Convert-FromJsonObject -InputObject ($configurationContent | ConvertFrom-Json) -TypeName 'UPCluster'
        if ($clusterConfiguration) {
            $clusterConfiguration.Path = $Path
            $excelFilePath = [System.IO.Path]::GetFullPath((Join-Path -Path (Split-Path -Path $Path -Parent) -ChildPath "$([System.IO.Path]::GetFileNameWithoutExtension($Path)).xlsx"))
            if (Test-Path -Path $excelFilePath -PathType Leaf) {
                Write-Verbose "Processing excel-file '$excelFilePath'."
                Add-NodesFromExcel -Cluster $clusterConfiguration -ExcelFilePath $excelFilePath
            }

            $clusterConfiguration.ReplaceExpressions($clusterConfiguration)

            $script:clusterConfiguration = $clusterConfiguration

            if ($PassThru.IsPresent) {
                return $script:clusterConfiguration
            }
        }
    }
    else {
        Write-Error "Path '$Path' does not exist."
    }
}
