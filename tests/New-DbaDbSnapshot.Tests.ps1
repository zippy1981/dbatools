$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

# Targets only instance2 because it's the only one where Snapshots can happen
Describe "$CommandName Integration Tests" -Tag "IntegrationTests" {
    Context "Parameter validation" {
        It "Stops if no Database or AllDatabases" {
            { New-DbaDbSnapshot -SqlInstance $script:instance2 -EnableException } | Should Throw "You must specify"
        }
        It "Is nice by default" {
            { New-DbaDbSnapshot -SqlInstance $script:instance2 *> $null } | Should Not Throw "You must specify"
        }
    }
    
    Context "Operations on not supported databases" {
        It "Doesn't support model, master or tempdb" {
            $result = New-DbaDbSnapshot -SqlInstance $script:instance2 -EnableException -Database model, master, tempdb
            $result | Should Be $null
        }
    }
    
    Context "Operations on databases" {
        BeforeAll {
            $server = Connect-DbaInstance -SqlInstance $script:instance2
            Get-DbaProcess -SqlInstance $script:instance2 | Where-Object Program -match dbatools | Stop-DbaProcess -Confirm:$false -WarningAction SilentlyContinue
            $db1 = "dbatoolsci_SnapMe"
            $db2 = "dbatoolsci_SnapMe2"
            $db3 = "dbatoolsci_SnapMe3_Offline"
            $server.Query("CREATE DATABASE $db1")
            $server.Query("CREATE DATABASE $db2")
            $server.Query("CREATE DATABASE $db3")
        }
        AfterAll {
            Remove-DbaDbSnapshot -SqlInstance $script:instance2 -Database $db1, $db2, $db3 -Confirm:$false
            Remove-DbaDatabase -Confirm:$false -SqlInstance $script:instance2 -Database $db1, $db2, $db3
        }
        
        It "Skips over offline databases nicely" {
            $server.Query("ALTER DATABASE $db3 SET OFFLINE WITH ROLLBACK IMMEDIATE")
            $result = New-DbaDbSnapshot -SqlInstance $script:instance2 -EnableException -Database $db3
            $result | Should Be $null
            $server.Query("ALTER DATABASE $db3 SET ONLINE WITH ROLLBACK IMMEDIATE")
        }
        
        It "Refuses to accept multiple source databases with a single name target" {
            { New-DbaDbSnapshot -SqlInstance $script:instance2 -EnableException -Database $db1, $db2 -Name "dbatools_Snapped" } | Should Throw
        }
        
        It "Halts when path is not accessible" {
            { New-DbaDbSnapshot -SqlInstance $script:instance2 -Database $db1 -Path B:\Funnydbatoolspath -EnableException } | Should Throw
        }
        
        It "Creates snaps for multiple dbs by default" {
            $results = New-DbaDbSnapshot -SqlInstance $script:instance2 -EnableException -Database $db1, $db2
            $results | Should Not Be $null
            foreach ($result in $results) {
                $result.SnapshotOf -in @($db1, $db2) | Should Be $true
            }
        }
        
        It "Creates snap with the correct name" {
            $result = New-DbaDbSnapshot -SqlInstance $script:instance2 -EnableException -Database $db1 -Name "dbatools_SnapMe_right"
            $result | Should Not Be $null
            $result.SnapshotOf | Should Be $db1
            $result.Name | Should Be "dbatools_SnapMe_right"
        }
        
        It "Creates snap with the correct name template" {
            $result = New-DbaDbSnapshot -SqlInstance $script:instance2 -EnableException -Database $db2 -NameSuffix "dbatools_SnapMe_{0}_funny"
            $result | Should Not Be $null
            $result.SnapshotOf | Should Be $db2
            $result.Name | Should Be ("dbatools_SnapMe_{0}_funny" -f $db2)
        }
        
        It "has the correct default properties" {
            $result = Get-DbaDbSnapshot -SqlInstance $script:instance2 -Database $db2 | Select-Object -First 1
            $ExpectedPropsDefault = 'ComputerName', 'CreateDate', 'InstanceName', 'Name', 'SnapshotOf', 'SqlInstance','DiskUsage'
            ($result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames | Sort-Object) | Should Be ($ExpectedPropsDefault | Sort-Object)
        }
    }
}