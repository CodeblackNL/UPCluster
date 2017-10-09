function Add-NodesFromExcel {
    param (
        [UPCluster]$Cluster,
        [string]$ExcelFilePath,
        [string]$ExcelSheetName
    )

    $excel = New-Object -ComObject Excel.Application

    try {
        $workbook = $excel.Workbooks.Open($ExcelFilePath)
        
        if ($ExcelSheetName) {
            $sheet = $workbook.Sheets[$ExcelSheetName]
        }
        else {
            $sheet = $workbook.Sheets.Item(1)
        }

        $columnMachineName = 0
        $columnIPAddress = 0
        $columnMacAddress = 0
        $columnUnattendFileName = 0
        $columnDomainName = 0
        $columnAdministratorPassword = 0
        $columnRoles = 0
        $columnProperties = @{}
        for ($column = 1; $column -lt 50; $column++) {
            $headerText = $sheet.Cells.Item(1, $column).Text
            switch ($headerText) {
                'MachineName'           { $columnMachineName = $column }
                'IPAddress'             { $columnIPAddress = $column }
                'MacAddress'            { $columnMacAddress = $column }
                'UnattendFileName'      { $columnUnattendFileName = $column }
                'Domain'                { $columnDomainName = $column }
                'DomainName'            { $columnDomainName = $column }
                'Password'              { $columnAdministratorPassword = $column }
                'AdministratorPassword' { $columnAdministratorPassword = $column }
                'Roles'                 { $columnRoles = $column }
                { $_ -match '^property:' } {
                    $columnProperties.($_.Substring(9).Trim()) = $column
                }
            }
        }

        $emptyCount = 0
        for ($row = 2; $row -lt 100; $row++) {
            $machineName = $sheet.Cells.Item($row, $columnMachineName).Text
            $ipAddress = $sheet.Cells.Item($row, $columnIPAddress).Text
            $macAddress = $sheet.Cells.Item($row, $columnMacAddress).Text
            $unattendFileName = $sheet.Cells.Item($row, $columnUnattendFileName).Text
            $domainName = $sheet.Cells.Item($row, $columnDomainName).Text
            if ($columnAdministratorPassword) {
                $administratorPassword = $sheet.Cells.Item($row, $columnAdministratorPassword).Text
            }
            $roles = @(($sheet.Cells.Item($row, $columnRoles).Text) -split ',' |% { $_.Trim() } |? { $_ })
            $properties = @{}
            foreach ($key in $columnProperties.Keys) {
                $propertyValue = $sheet.Cells.Item($row, $columnProperties.$key).Text
                if ($propertyValue) {
                    $properties.$key = $propertyValue
                }
            }

            if ($macAddress -eq '  -  -  -  -  -  ') {
                $macAddress = $null
            }

            if (-not $machineName -and -not $ipAddress -and -not $macAddress -and -not $unattendFileName) {
                $emptyCount++
                if ($emptyCount -gt 40) {
                    break
                }
                else {
                    continue
                }
            }
            elseif (-not $machineName -or -not $ipAddress -or -not $macAddress -or -not $unattendFileName) {
                continue
            }

            if ($domainName) {
                $domain = $Cluster.Domains.$domainName
                $secureAdministratorPassword = $domain.AdministratorPassword
            }
            if ($administratorPassword) {
                $secureAdministratorPassword = ConvertTo-SecureString -String $administratorPassword -AsPlainText -Force
            }
            if (-not $secureAdministratorPassword -and $Cluster.Domains.Length -eq 1) {
                $domain = $Cluster.Domains[0].AdministratorPassword
            }

            $properties.UnattendFileName = $unattendFileName

            $node = New-Object -TypeName 'UPClusterNode' -Property @{
                Name = $machineName
                AdministratorPassword = $secureAdministratorPassword
                Domain = $Cluster.Domains.$domain
                Roles = @($roles | ForEach-Object {
                    $roleName = $_
                    $role = $Cluster.Roles | Where-Object { $_.Name -eq $roleName }
                    if (-not $role) {
                        $role = New-Object -TypeName 'UPClusterRole' -Property @{ Name = $roleName }
                    }
                    $role
                })
                NetworkAdapters = @(
                    New-Object -TypeName 'UPClusterNetworkAdapter' -Property @{
                        Network = $Cluster.Networks.Ethernet
                        StaticMacAddress = $macAddress
                        StaticIPAddress = $ipAddress
                    }
                )
                Properties = $properties
                AllProperties = $properties
            }
            $Cluster.Nodes += $node
        }
    }
    finally {
        $workbook.Close()
    }
}
