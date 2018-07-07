function Get-DbaErrorLogConfig {
    <#
        .SYNOPSIS
            Pulls the configuration for the ErrorLog on a given SQL Server instance
    
        .DESCRIPTION
            Pulls the configuration for the ErrorLog on a given SQL Server instance.

            Includes error log path, number of log files configured and size (SQL Server 2012+ only)

        .PARAMETER SqlInstance
            The target SQL Server instance(s)

        .PARAMETER SqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: Instance, ErrorLog
            Author: Shawn Melton (@wsmelton)

            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Get-DbaErrorLogConfig

       .EXAMPLE
            Get-DbaErrorLogConfig -SqlInstance server2017,server2014

            Returns error log configuration for server2017 and server2014
    #>
    [cmdletbinding()]
    param (
        [Parameter(ValueFromPipeline, Mandatory)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
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

            $numLogs = $server.NumberOfLogFiles
            $logSize =
            if ($server.VersionMajor -ge 11) {
                [dbasize]($server.ErrorLogSizeKb * 1024)
            }
            else {
                $null
            }

            [PSCustomObject]@{
                ComputerName       = $server.NetName
                InstanceName       = $server.ServiceName
                SqlInstance        = $server.DomainInstanceName
                LogCount           = $numLogs
                LogSize            = $logSize
                LogPath            = $server.ErrorLogPath
            }
        }
    }
}