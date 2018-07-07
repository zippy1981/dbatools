#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function Get-DbaSqlInstanceProperty {
    <#
        .SYNOPSIS
            Gets SQL Server instance properties of one or more instance(s) of SQL Server.

        .DESCRIPTION
            The Get-DbaSqlInstanceProperty command gets SQL Server instance properties from the SMO object sqlserver.

        .PARAMETER SqlInstance
            SQL Server name or SMO object representing the SQL Server to connect to. This can be a collection and receive pipeline input to allow the function to be executed against multiple SQL Server instances.

        .PARAMETER SqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER InstanceProperty
            SQL Server instance property(ies) to include.

        .PARAMETER ExcludeInstanceProperty
            SQL Server instance property(ies) to exclude.

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: Instance, Configure, Configuration
            Author: Klaas Vandenberghe (@powerdbaklaas)

            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Get-DbaSqlInstanceProperty

        .EXAMPLE
            Get-DbaSqlInstanceProperty -SqlInstance localhost

            Returns SQL Server instance properties on the local default SQL Server instance

        .EXAMPLE
            Get-DbaSqlInstanceProperty -SqlInstance sql2, sql4\sqlexpress

            Returns SQL Server instance properties on default instance on sql2 and sqlexpress instance on sql4

        .EXAMPLE
            'sql2','sql4' | Get-DbaSqlInstanceProperty

            Returns SQL Server instance properties on sql2 and sql4

        .EXAMPLE
            Get-DbaSqlInstanceProperty -SqlInstance sql2,sql4 -InstanceProperty DefaultFile

            Returns SQL Server instance property DefaultFile on instance sql2 and sql4

        .EXAMPLE
            Get-DbaSqlInstanceProperty -SqlInstance sql2,sql4 -ExcludeInstanceProperty DefaultFile

            Returns all SQL Server instance properties except DefaultFile on instance sql2 and sql4

        .EXAMPLE
            $cred = Get-Credential sqladmin
            Get-DbaSqlInstanceProperty -SqlInstance sql2 -SqlCredential $cred

            Connects using sqladmin credential and returns SQL Server instance properties from sql2
    #>
    [CmdletBinding(DefaultParameterSetName = "Default")]
    param (
        [parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [object[]]$InstanceProperty,
        [object[]]$ExcludeInstanceProperty,
        [Alias('Silent')]
        [switch]$EnableException
    )
    process {
        foreach ($instance in $SqlInstance) {
            Write-Message -Level Verbose -Message "Connecting to $instance"

            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            try {
                $infoProperties = $server.Information.Properties

                if ($InstanceProperty) {
                    $infoProperties = $infoProperties | Where-Object Name -In $InstanceProperty
                }
                if ($ExcludeInstanceProperty) {
                    $infoProperties = $infoProperties | Where-Object Name -NotIn $ExcludeInstanceProperty
                }
                foreach ($prop in $infoProperties) {
                    Add-Member -Force -InputObject $prop -MemberType NoteProperty -Name ComputerName -Value $server.NetName
                    Add-Member -Force -InputObject $prop -MemberType NoteProperty -Name InstanceName -Value $server.ServiceName
                    Add-Member -Force -InputObject $prop -MemberType NoteProperty -Name SqlInstance -Value $server.DomainInstanceName
                    Add-Member -Force -InputObject $prop -MemberType NoteProperty -Name PropertyType -Value 'Information'
                    Select-DefaultView -InputObject $prop -Property ComputerName, InstanceName, SqlInstance, Name, Value, PropertyType
                }
            }
            catch {
                Stop-Function -Message "Issue gathering information properties for $instance." -Target $instance -ErrorRecord $_ -Continue
            }

            try {
                $userProperties = $server.UserOptions.Properties

                if ($InstanceProperty) {
                    $userProperties = $userProperties | Where-Object Name -In $InstanceProperty
                }
                if ($ExcludeInstanceProperty) {
                    $userProperties = $userProperties | Where-Object Name -NotIn $ExcludeInstanceProperty
                }
                foreach ($prop in $userProperties) {
                    Add-Member -Force -InputObject $prop -MemberType NoteProperty -Name ComputerName -Value $server.NetName
                    Add-Member -Force -InputObject $prop -MemberType NoteProperty -Name InstanceName -Value $server.ServiceName
                    Add-Member -Force -InputObject $prop -MemberType NoteProperty -Name SqlInstance -Value $server.DomainInstanceName
                    Add-Member -Force -InputObject $prop -MemberType NoteProperty -Name PropertyType -Value 'UserOption'
                    Select-DefaultView -InputObject $prop -Property ComputerName, InstanceName, SqlInstance, Name, Value, PropertyType
                }
            }
            catch {
                Stop-Function -Message "Issue gathering user options for $instance." -Target $instance -ErrorRecord $_ -Continue
            }

            try {
                $settingProperties = $server.Settings.Properties

                if ($InstanceProperty) {
                    $settingProperties = $settingProperties | Where-Object Name -In $InstanceProperty
                }
                if ($ExcludeInstanceProperty) {
                    $settingProperties = $settingProperties | Where-Object Name -NotIn $ExcludeInstanceProperty
                }
                foreach ($prop in $settingProperties) {
                    Add-Member -Force -InputObject $prop -MemberType NoteProperty -Name ComputerName -Value $server.NetName
                    Add-Member -Force -InputObject $prop -MemberType NoteProperty -Name InstanceName -Value $server.ServiceName
                    Add-Member -Force -InputObject $prop -MemberType NoteProperty -Name SqlInstance -Value $server.DomainInstanceName
                    Add-Member -Force -InputObject $prop -MemberType NoteProperty -Name PropertyType -Value 'Setting'
                    Select-DefaultView -InputObject $prop -Property ComputerName, InstanceName, SqlInstance, Name, Value, PropertyType
                }
            }
            catch {
                Stop-Function -Message "Issue gathering settings for $instance." -Target $instance -ErrorRecord $_ -Continue
            }
        }
    }
}