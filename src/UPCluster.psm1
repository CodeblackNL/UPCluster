#Requires -Version 5.0

$script:clusterConfiguration = $null
$script:defaultConfigurationFileName = 'cluster.json'
$script:sessions = @{}

. "$PSScriptRoot\Classes.ps1"

Get-ChildItem -Path "$PSScriptRoot\Internal" -Filter '*.ps1' -Recurse | ForEach-Object {
    . $_.FullName
}

Get-ChildItem -Path "$PSScriptRoot\Functions" -Filter '*.ps1' -Recurse | ForEach-Object {
    . $_.FullName
    Export-ModuleMember -Function ([System.IO.Path]::GetFileNameWithoutExtension($_.Name))
}
