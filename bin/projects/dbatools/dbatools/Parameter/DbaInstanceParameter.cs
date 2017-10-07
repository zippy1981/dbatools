using System;
using System.Management.Automation;
using System.Net;
using System.Net.NetworkInformation;
using System.Text.RegularExpressions;
using Sqlcollaborative.Dbatools.Connection;
using Sqlcollaborative.Dbatools.Exceptions;
using Sqlcollaborative.Dbatools.Utility;

namespace Sqlcollaborative.Dbatools.Parameter
{
    /// <summary>
    /// Input converter for instance information
    /// </summary>
    public class DbaInstanceParameter
    {
        #region Fields of contract
        /// <summary>
        /// Name of the computer as resolvable by DNS
        /// </summary>
        [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
        public string ComputerName
        {
            get { return _computerName; }
        }

        /// <summary>
        /// Name of the instance on the target server
        /// </summary>
        [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Optional)]
        public string InstanceName
        {
            get
            {
                if (String.IsNullOrEmpty(_instanceName))
                    return "MSSQLSERVER";
                return _instanceName;
            }
        }

        /// <summary>
        /// The port over which to connect to the server. Only present if non-default
        /// </summary>
        [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Optional)]
        public int Port
        {
            get
            {
                if (_port == 0 && String.IsNullOrEmpty(_instanceName))
                    return 1433;
                return _port;
            }
        }

        /// <summary>
        /// The network protocol to connect over
        /// </summary>
        [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
        public SqlConnectionProtocol NetworkProtocol
        {
            get
            {
                return _networkProtocol;
            }
        }

        /// <summary>
        /// Verifies, whether the specified computer is localhost or not.
        /// </summary>
        [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
        public bool IsLocalHost
        {
            get
            {
                return Utility.Validation.IsLocalhost(_computerName);
            }
        }

        /// <summary>
        /// Full name of the instance, including the server-name
        /// </summary>
        [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
        public string FullName
        {
            get
            {
                string temp = _computerName;
                if (_port > 0) { temp += (":" + _port); }
                if (!String.IsNullOrEmpty(_instanceName)) { temp += ("\\" + _instanceName); }
                return temp;
            }
        }

        /// <summary>
        /// Full name of the instance, including the server-name, used when connecting via SMO
        /// </summary>
        [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
        public string FullSmoName
        {
            get
            {
                string temp = _computerName;
                if (_networkProtocol == SqlConnectionProtocol.NP) { temp = "NP:" + temp; }
                if (_networkProtocol == SqlConnectionProtocol.TCP) { temp = "TCP:" + temp; }
                if (!String.IsNullOrEmpty(_instanceName) && _port > 0) { return String.Format(@"{0}\{1},{2}", temp, _instanceName, _port); }
                if (_port > 0) { return temp + "," + _port; }
                if (!String.IsNullOrEmpty(_instanceName)) { return temp + "\\" + _instanceName; }
                return temp;
            }
        }

        /// <summary>
        /// Name of the computer as used in an SQL Statement
        /// </summary>
        [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
        public string SqlComputerName
        {
            get { return "[" + _computerName + "]"; }
        }

        /// <summary>
        /// Name of the instance as used in an SQL Statement
        /// </summary>
        [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
        public string SqlInstanceName
        {
            get
            {
                if (String.IsNullOrEmpty(_instanceName))
                    return "[MSSQLSERVER]";
                return "[" + _instanceName + "]";
            }
        }

        /// <summary>
        /// Full name of the instance, including the server-name as used in an SQL statement
        /// </summary>
        [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
        public string SqlFullName
        {
            get
            {
                if (String.IsNullOrEmpty(_instanceName)) { return "[" + _computerName + "]"; }
                return "[" + _computerName + "\\" + _instanceName + "]";
            }
        }

        /// <summary>
        /// Whether the input is a connection string
        /// </summary>
        [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
        public bool IsConnectionString { get; private set; } //TODO: figure out how to not limit ourselves to .NET 4.0

        /// <summary>
        /// The original object passed to the parameter class.
        /// </summary>
        [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
        public object InputObject;
        #endregion Fields of contract

        private readonly string _computerName;
        private readonly string _instanceName;
        private readonly int _port;
        private readonly SqlConnectionProtocol _networkProtocol = SqlConnectionProtocol.Any;

        #region Uncontracted properties
        /// <summary>
        /// What kind of object was bound to the parameter class? For efficiency's purposes.
        /// </summary>
        public DbaInstanceInputType Type
        {
            get
            {
                try
                {
                    PSObject tempObject = new PSObject(InputObject);
                    string typeName = tempObject.TypeNames[0].ToLower();

                    switch (typeName)
                    {
                        case "microsoft.sqlserver.management.smo.server":
                            return DbaInstanceInputType.Server;
                        case "microsoft.sqlserver.management.smo.linkedserver":
                            return DbaInstanceInputType.Linked;
                        case "microsoft.sqlserver.management.registeredservers.registeredserver":
                            return DbaInstanceInputType.RegisteredServer;
                        default:
                            return DbaInstanceInputType.Default;
                    }
                }
                catch { return DbaInstanceInputType.Default; }
            }
        }

        /// <summary>
        /// Returns, whether a live SMO object was bound for the purpose of accessing LinkedServer functionality
        /// </summary>
        public bool LinkedLive
        {
            get
            {
                return (((DbaInstanceInputType.Linked | DbaInstanceInputType.Server) & Type) != 0);
            }
        }

        /// <summary>
        /// Returns the available Linked Server objects from live objects only
        /// </summary>
        public object LinkedServer
        {
            get
            {
                switch (Type)
                {
                    case DbaInstanceInputType.Linked:
                        return InputObject;
                    case DbaInstanceInputType.Server:
                        PSObject tempObject = new PSObject(InputObject);
                        return tempObject.Properties["LinkedServers"].Value;
                    default:
                        return null;
                }
            }
        }
        #endregion Uncontracted properties

        /// <summary>
        /// Converts the parameter class to its full name
        /// </summary>
        /// <param name="input">The parameter class object to convert</param>
        [ParameterContract(ParameterContractType.Operator, ParameterContractBehavior.Conversion)]
        public static implicit operator string(DbaInstanceParameter input)
        {
            return input.FullName;
        }

        #region Constructors
        /// <summary>
        /// Creates a DBA Instance Parameter from string
        /// </summary>
        /// <param name="name">The name of the instance</param>
        public DbaInstanceParameter(string name)
        {
            InputObject = name;

            if (string.IsNullOrWhiteSpace(name))
                throw new BloodyHellGiveMeSomethingToWorkWithException("Please provide an instance name", "DbaInstanceParameter");

            if (name == ".")
            {
                _computerName = name;
                _networkProtocol = SqlConnectionProtocol.NP;
                return;
            }

            string tempString = name.Trim();
            tempString = Regex.Replace(tempString, @"^\[(.*)\]$", "$1");

            // Named Pipe path notation interpretation
            if (Regex.IsMatch(tempString, @"^\\\\[^\\]+\\pipe\\([^\\]+\\){0,1}sql\\query$", RegexOptions.IgnoreCase))
            {
                try
                {
                    _networkProtocol = SqlConnectionProtocol.NP;

                    _computerName = Regex.Match(tempString, @"^\\\\([^\\]+)\\").Groups[1].Value;

                    if (Regex.IsMatch(tempString, @"\\MSSQL\$[^\\]+\\", RegexOptions.IgnoreCase))
                        _instanceName = Regex.Match(tempString, @"\\MSSQL\$([^\\]+)\\", RegexOptions.IgnoreCase).Groups[1].Value;
                }
                catch (Exception e)
                {
                    throw new ArgumentException(String.Format("Failed to interpret named pipe path notation: {0} | {1}", InputObject, e.Message), e);
                }

                return;
            }

            // Connection String interpretation
            try
            {
                System.Data.SqlClient.SqlConnectionStringBuilder connectionString =
                    new System.Data.SqlClient.SqlConnectionStringBuilder(tempString);
                DbaInstanceParameter tempParam = new DbaInstanceParameter(connectionString.DataSource);
                _computerName = tempParam.ComputerName;
                if (tempParam.InstanceName != "MSSQLSERVER")
                {
                    _instanceName = tempParam.InstanceName;
                }
                if (tempParam.Port != 1433)
                {
                    _port = tempParam.Port;
                }
                _networkProtocol = tempParam.NetworkProtocol;

                IsConnectionString = true;

                return;
            }
            catch (ArgumentException ex)
            {
                string argName = "unknown";
                try
                {
                    argName = ex.TargetSite.GetParameters()[0].Name;
                }
                catch
                {
                }
                if (argName == "keyword")
                {
                    throw;
                }
            }
            catch (FormatException)
            {
                throw;
            }
            catch { }

            // Handle and clear protocols. Otherwise it'd make port detection unneccessarily messy
            if (Regex.IsMatch(tempString, "^TCP:", RegexOptions.IgnoreCase)) //TODO: Use case insinsitive String.BeginsWith()
            {
                _networkProtocol = SqlConnectionProtocol.TCP;
                tempString = tempString.Substring(4);
            }
            if (Regex.IsMatch(tempString, "^NP:", RegexOptions.IgnoreCase)) // TODO: Use case insinsitive String.BeginsWith()
            {
                _networkProtocol = SqlConnectionProtocol.NP;
                tempString = tempString.Substring(3);
            }

            // Case: Default instance | Instance by port
            if (tempString.Split('\\').Length == 1)
            {
                if (Regex.IsMatch(tempString, @"[:,]\d{1,5}$") && !Regex.IsMatch(tempString, RegexHelper.IPv6) && ((tempString.Split(':').Length == 2) || (tempString.Split(',').Length == 2)))
                {
                    var delimiter = Regex.IsMatch(tempString, @"[:]\d{1,5}$") ? ':' : ',';

                    try
                    {
                        Int32.TryParse(tempString.Split(delimiter)[1], out _port);
                        if (_port > 65535) { throw new PSArgumentException("Failed to parse instance name: " + tempString); }
                        tempString = tempString.Split(delimiter)[0];
                    }
                    catch
                    {
                        throw new PSArgumentException("Failed to parse instance name: " + name);
                    }
                }

                if (Utility.Validation.IsValidComputerTarget(tempString))
                {
                    _computerName = tempString;
                }

                else
                {
                    throw new PSArgumentException("Failed to parse instance name: " + name);
                }
            }

            // Case: Named instance
            else if (tempString.Split('\\').Length == 2)
            {
                string tempComputerName = tempString.Split('\\')[0];
                string tempInstanceName = tempString.Split('\\')[1];

                if (Regex.IsMatch(tempComputerName, @"[:,]\d{1,5}$") && !Regex.IsMatch(tempComputerName, RegexHelper.IPv6))
                {
                    var delimiter = Regex.IsMatch(tempComputerName, @"[:]\d{1,5}$") ? ':' : ',';

                    try
                    {
                        Int32.TryParse(tempComputerName.Split(delimiter)[1], out _port);
                        if (_port > 65535) { throw new PSArgumentException("Failed to parse instance name: " + name); }
                        tempComputerName = tempComputerName.Split(delimiter)[0];
                    }
                    catch
                    {
                        throw new PSArgumentException("Failed to parse instance name: " + name);
                    }
                }
                else if (Regex.IsMatch(tempInstanceName, @"[:,]\d{1,5}$") && !Regex.IsMatch(tempInstanceName, RegexHelper.IPv6))
                {
                    var delimiter = Regex.IsMatch(tempString, @"[:]\d{1,5}$") ? ':' : ',';

                    try
                    {
                        Int32.TryParse(tempInstanceName.Split(delimiter)[1], out _port);
                        if (_port > 65535) { throw new PSArgumentException("Failed to parse instance name: " + name); }
                        tempInstanceName = tempInstanceName.Split(delimiter)[0];
                    }
                    catch
                    {
                        throw new PSArgumentException("Failed to parse instance name: " + name);
                    }
                }

                if (Utility.Validation.IsValidComputerTarget(tempComputerName) && Utility.Validation.IsValidInstanceName(tempInstanceName, true))
                {
                    _computerName = tempComputerName;
                    if ((tempInstanceName.ToLower() != "default") && (tempInstanceName.ToLower() != "mssqlserver"))
                        _instanceName = tempInstanceName;
                }

                else
                {
                    throw new PSArgumentException(string.Format("Failed to parse instance name: {0}. Computer Name: {1}, Instance {2}", name, tempComputerName, tempInstanceName));
                }
            }

            // Case: Bad input
            else { throw new PSArgumentException("Failed to parse instance name: " + name); }
        }

        /// <summary>
        /// Creates a DBA Instance Parameter from an IPAddress
        /// </summary>
        /// <param name="address"></param>
        public DbaInstanceParameter(IPAddress address)
        {
            _computerName = address.ToString();
        }

        /// <summary>
        /// Creates a DBA Instance Parameter from the reply to a ping
        /// </summary>
        /// <param name="ping">The result of a ping</param>
        public DbaInstanceParameter(PingReply ping)
        {
            _computerName = ping.Address.ToString();
        }

        /// <summary>
        /// Creates a DBA Instance Parameter from the result of a dns resolution
        /// </summary>
        /// <param name="entry">The result of a dns resolution, to be used for targetting the default instance</param>
        public DbaInstanceParameter(IPHostEntry entry)
        {
            _computerName = entry.HostName;
        }

        /// <summary>
        /// Creates a DBA Instance parameter from any object
        /// </summary>
        /// <param name="input">Object to parse</param>
        public DbaInstanceParameter(object input)
        {
            InputObject = input;
            PSObject tempInput = new PSObject(input);
            string typeName;

            try { typeName = tempInput.TypeNames[0].ToLower(); }
            catch
            {
                throw new PSArgumentException("Failed to interpret input as Instance: " + input);
            }

            typeName = typeName.Replace("Deserialized.", "");

            switch (typeName)
            {
                case "microsoft.sqlserver.management.smo.server":
                    try
                    {
                        if (tempInput.Properties["NetName"] != null) { _computerName = (string)tempInput.Properties["NetName"].Value; }
                        else { _computerName = (new DbaInstanceParameter((string)tempInput.Properties["DomainInstanceName"].Value)).ComputerName; }
                        _instanceName = (string)tempInput.Properties["InstanceName"].Value;
                        PSObject tempObject = new PSObject(tempInput.Properties["ConnectionContext"].Value);

                        string tempConnectionString = (string)tempObject.Properties["ConnectionString"].Value;
                        tempConnectionString = tempConnectionString.Split(';')[0].Split('=')[1].Trim().Replace(" ", "");

                        if (Regex.IsMatch(tempConnectionString, @",\d{1,5}$") && (tempConnectionString.Split(',').Length == 2))
                        {
                            try { Int32.TryParse(tempConnectionString.Split(',')[1], out _port); }
                            catch (Exception e)
                            {
                                throw new PSArgumentException("Failed to parse port number on connection string: " + tempConnectionString, e);
                            }
                            if (_port > 65535) { throw new PSArgumentException("Failed to parse port number on connection string: " + tempConnectionString); }
                        }
                    }
                    catch (Exception e)
                    {
                        throw new PSArgumentException("Failed to interpret input as Instance: " + input + " : " + e.Message, e);
                    }
                    break;
                case "microsoft.sqlserver.management.smo.linkedserver":
                    try
                    {
                        _computerName = (string)tempInput.Properties["Name"].Value;
                    }
                    catch (Exception e)
                    {
                        throw new PSArgumentException("Failed to interpret input as Instance: " + input, e);
                    }
                    break;
                case "microsoft.activedirectory.management.adcomputer":
                    try
                    {
                        _computerName = (string)tempInput.Properties["Name"].Value;

                        // We prefer using the dnshostname whenever possible
                        if (!String.IsNullOrEmpty((string) tempInput.Properties["DNSHostName"].Value))
                            _computerName = (string)tempInput.Properties["DNSHostName"].Value;
                    }
                    catch (Exception e)
                    {
                        throw new PSArgumentException("Failed to interpret input as Instance: " + input, e);
                    }
                    break;
                case "microsoft.sqlserver.management.registeredservers.registeredserver":
                    try
                    {
                        //Pass the ServerName property of the SMO object to the string constrtuctor, 
                        //so we don't have to re-invent the wheel on instance name / port parsing
                        DbaInstanceParameter parm =
                            new DbaInstanceParameter((string) tempInput.Properties["ServerName"].Value);
                        _computerName = parm.ComputerName;

                        if (parm.InstanceName != "MSSQLSERVER")
                            _instanceName = parm.InstanceName;

                        if (parm.Port != 1433)
                            _port = parm.Port;
                    }
                    catch (Exception e)
                    {
                        throw new PSArgumentException("Failed to interpret input as Instance: " + input, e);
                    }
                    break;
                default:
                    throw new PSArgumentException("Failed to interpret input as Instance: " + input);
            }
        }
        #endregion Constructors

        /// <summary>
        /// Overrides the regular tostring to show something pleasant and useful
        /// </summary>
        /// <returns>The full SMO name</returns>
        public override string ToString()
        {
            return FullSmoName;
        }
    }
}