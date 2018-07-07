﻿$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Integration Tests" -Tag "IntegrationTests" {
    Context "Setup" {
        BeforeAll {
            $group = "dbatoolsci-group1"
            $group2 = "dbatoolsci-group2"
            $description = "group description"
        }
        AfterAll {
            Get-DbaRegisteredServerGroup -SqlInstance $script:instance1 | Where-Object Name -match dbatoolsci | Remove-DbaRegisteredServerGroup -Confirm:$false
        }
        
        It "adds a registered server group" {
            $results = Add-DbaRegisteredServerGroup -SqlInstance $script:instance1 -Name $group
            $results.Name | Should -Be $group
            $results.SqlInstance | Should -Not -Be $null
        }
        It "adds a registered server group with extended properties" {
            $results = Add-DbaRegisteredServerGroup -SqlInstance $script:instance1 -Name $group2 -Description $description
            $results.Name | Should -Be $group2
            $results.Description | Should -Be $description
            $results.SqlInstance | Should -Not -Be $null
        }
        It "supports hella pipe" {
            $results = Get-DbaRegisteredServerGroup -SqlInstance $script:instance1 -Id 1 | Add-DbaRegisteredServerGroup -Name dbatoolsci-first | Add-DbaRegisteredServerGroup -Name dbatoolsci-second | Add-DbaRegisteredServerGroup -Name dbatoolsci-third | Add-DbaRegisteredServer -ServerName dbatoolsci-test -Description ridiculous
            $results.Group | Should -Be 'dbatoolsci-first\dbatoolsci-second\dbatoolsci-third'
        }
    }
}