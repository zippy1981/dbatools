﻿$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"
Describe "$commandname Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        $sql = "CREATE RESOURCE POOL dbatoolsci_prod
                WITH
                (
                     MAX_CPU_PERCENT = 100,
                     MIN_CPU_PERCENT = 50
                )"
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2 -Query $sql
        $sql = "CREATE WORKLOAD GROUP dbatoolsci_prodprocessing
                WITH
                (
                     IMPORTANCE = MEDIUM
                ) USING dbatoolsci_prod"
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2 -Query $sql
        $sql = "CREATE RESOURCE POOL dbatoolsci_offhoursprocessing
                WITH
                (
                     MAX_CPU_PERCENT = 50,
                     MIN_CPU_PERCENT = 0
                )"
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2 -Query $sql
        $sql = "CREATE WORKLOAD GROUP dbatoolsci_goffhoursprocessing
                WITH
                (
                     IMPORTANCE = LOW
                )
                USING dbatoolsci_offhoursprocessing"
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2 -Query $sql
        $sql = "ALTER RESOURCE GOVERNOR RECONFIGURE"
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2 -Query $sql
        $sql = "CREATE FUNCTION dbatoolsci_fnRG()
                RETURNS sysname
                WITH SCHEMABINDING
                AS
                BEGIN
                     RETURN N'dbatoolsci_goffhoursprocessing'
                END"
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2 -Query $sql
        $sql = "ALTER RESOURCE GOVERNOR with (CLASSIFIER_FUNCTION = dbo.dbatoolsci_fnRG); ALTER RESOURCE GOVERNOR RECONFIGURE;"
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2 -Query $sql
    }
    AfterAll {
        Get-DbaProcess -SqlInstance $script:instance2, $script:instance3 |  Stop-DbaProcess -WarningAction SilentlyContinue
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2, $script:instance3 -Query "ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = NULL); ALTER RESOURCE GOVERNOR RECONFIGURE"
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2, $script:instance3 -Query "DROP FUNCTION [dbo].[dbatoolsci_fnRG];ALTER RESOURCE GOVERNOR RECONFIGURE"
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2, $script:instance3 -Query "DROP WORKLOAD GROUP [dbatoolsci_prodprocessing];ALTER RESOURCE GOVERNOR RECONFIGURE"
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2, $script:instance3 -Query "DROP WORKLOAD GROUP [dbatoolsci_goffhoursprocessing];ALTER RESOURCE GOVERNOR RECONFIGURE"
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2, $script:instance3 -Query "DROP RESOURCE POOL [dbatoolsci_offhoursprocessing];ALTER RESOURCE GOVERNOR RECONFIGURE"
        Invoke-DbaSqlQuery -WarningAction SilentlyContinue -SqlInstance $script:instance2, $script:instance3 -Query "DROP RESOURCE POOL [dbatoolsci_prod];ALTER RESOURCE GOVERNOR RECONFIGURE"
    }

    Context "Command works" {
        It "copies the resource governor successfully" {
            $results = Copy-DbaResourceGovernor -Source $script:instance2 -Destination $script:instance3 -Force -WarningAction SilentlyContinue
            $results.Status.Count | Should -BeGreaterThan 3
            $results.Name | Should -Contain 'dbatoolsci_prod'
        }
        It "returns the proper classifier function" {
            $results = Get-DbaResourceGovernorClassifierFunction -SqlInstance $script:instance3
            $results.Name | Should -Be 'dbatoolsci_fnRG'
        }
    }
}