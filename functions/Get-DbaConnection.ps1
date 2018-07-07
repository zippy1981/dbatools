﻿#ValidationTags#CodeStyle,Messaging,FlowControl,Pipeline#
function Get-DbaConnection {
    <#
        .SYNOPSIS
            Returns a bunch of information from dm_exec_connections.

        .DESCRIPTION
            Returns a bunch of information from dm_exec_connections which, according to Microsoft:
            "Returns information about the connections established to this instance of SQL Server and the details of each connection. Returns server wide connection information for SQL Server. Returns current database connection information for SQL Database."
    
        .PARAMETER SqlInstance
            The target SQL Server instance. Server(s) must be SQL Server 2005 or higher.

        .PARAMETER SqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: Connection
            dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
            Copyright (C) 2016 Chrissy LeMaire
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Get-DbaConnection

        .EXAMPLE
            Get-DbaConnection -SqlInstance sql2016, sql2017
            
            Returns client connection information from sql2016 and sql2017
    #>
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,
        [Alias("Credential", "Cred")]
        [PSCredential]$SqlCredential,
        [switch]$EnableException
    )
    
    begin {
        $sql = "SELECT  SERVERPROPERTY('MachineName') AS ComputerName,
                            ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') AS InstanceName,
                            SERVERPROPERTY('ServerName') AS SqlInstance,
                            session_id as SessionId, most_recent_session_id as MostRecentSessionId, connect_time as ConnectTime,
                            net_transport as Transport, protocol_type as ProtocolType, protocol_version as ProtocolVersion,
                            endpoint_id as EndpointId, encrypt_option as EncryptOption, auth_scheme as AuthScheme, node_affinity as NodeAffinity,
                            num_reads as Reads, num_writes as Writes, last_read as LastRead, last_write as LastWrite,
                            net_packet_size as PacketSize, client_net_address as ClientNetworkAddress, client_tcp_port as ClientTcpPort,
                            local_net_address as ServerNetworkAddress, local_tcp_port as ServerTcpPort, connection_id as ConnectionId,
                            parent_connection_id as ParentConnectionId, most_recent_sql_handle as MostRecentSqlHandle
                            FROM sys.dm_exec_connections"
    }
    
    process {
        foreach ($instance in $SqlInstance) {
            
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential -MinimumVersion 9
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }
            
            Write-Message -Level Debug -Message "Getting results for the following query: $sql."
            try {
                $server.Query($sql)
            }
            catch {
                Stop-Function -Message "Failure" -Target $server -Exception $_ -Continue
            }
        }
    }
}