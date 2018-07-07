﻿$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        $srvName = "dbatoolsci-server1"
        $group = "dbatoolsci-group1"
        $regSrvName = "dbatoolsci-server12"
        $regSrvDesc = "dbatoolsci-server123"
        
        $newGroup = Add-DbaRegisteredServerGroup -SqlInstance $script:instance1 -Name $group
        $newServer = Add-DbaRegisteredServer -SqlInstance $script:instance1 -ServerName $srvName -Name $regSrvName -Description $regSrvDesc
        
        $srvName2 = "dbatoolsci-server2"
        $group2 = "dbatoolsci-group1a"
        $regSrvName2 = "dbatoolsci-server21"
        $regSrvDesc2 = "dbatoolsci-server321"
        
        $newGroup2 = Add-DbaRegisteredServerGroup -SqlInstance $script:instance1 -Name $group2
        $newServer2 = Add-DbaRegisteredServer -SqlInstance $script:instance1 -ServerName $srvName2 -Name $regSrvName2 -Description $regSrvDesc2
        
        $regSrvName3 = "dbatoolsci-server3"
        $srvName3 = "dbatoolsci-server3"
        $regSrvDesc3 = "dbatoolsci-server3desc"
        
        $newServer3 = Add-DbaRegisteredServer -SqlInstance $script:instance1 -ServerName $srvName3 -Name $regSrvName3 -Description $regSrvDesc3
    }
    AfterAll {
        Get-DbaRegisteredServer -SqlInstance $script:instance1, $script:instance2 | Where-Object Name -match dbatoolsci | Remove-DbaRegisteredServer -Confirm:$false
        Get-DbaRegisteredServerGroup -SqlInstance $script:instance1, $script:instance2 | Where-Object Name -match dbatoolsci | Remove-DbaRegisteredServerGroup -Confirm:$false
        $results, $results2, $results3 | Remove-Item -ErrorAction Ignore
    }
    
    It -Skip "should create an xml file" {
        $results = $newServer | Export-DbaRegisteredServer
        $results -is [System.IO.FileInfo] | Should -Be $true
        $results.Extension -eq '.xml' | Should -Be $true
    }
    
    It "should create a specific xml file when using Path" {
        $results2 = $newGroup2 | Export-DbaRegisteredServer -Path C:\temp\dbatoolsci_regserverexport.xml
        $results2 -is [System.IO.FileInfo] | Should -Be $true
        $results2.FullName | Should -Be 'C:\temp\dbatoolsci_regserverexport.xml'
        Get-Content -Path $results2 -Raw | Should -Match dbatoolsci-group1a
    }
    
    It "creates an importable xml file" {
        $results3 = $newServer3 | Export-DbaRegisteredServer -Path C:\temp\dbatoolsci_regserverexport.xml
        $results4 = Import-DbaRegisteredServer -SqlInstance $script:instance2 -Path $results3
        $results4.ServerName | Should -Be $newServer3.ServerName
        $results4.Description | Should -Be $newServer3.Description
    }
}