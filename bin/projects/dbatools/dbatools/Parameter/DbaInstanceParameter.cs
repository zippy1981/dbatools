﻿using System;

namespace Sqlcollaborative.Dbatools
{
    namespace Parameter
    {
        using Connection;
        using System.Management.Automation;
        using System.Text.RegularExpressions;
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
                get { return _ComputerName; }
            }

            /// <summary>
            /// Name of the instance on the target server
            /// </summary>
            [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Optional)]
            public string InstanceName
            {
                get
                {
                    if (String.IsNullOrEmpty(_InstanceName))
                        return "MSSQLSERVER";
                    return _InstanceName;
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
                    if (_Port == 0 && String.IsNullOrEmpty(_InstanceName))
                        return 1433;
                    return _Port;
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
                    return _NetworkProtocol;
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
                    return Utility.Validation.IsLocalhost(_ComputerName);
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
                    string temp = _ComputerName;
                    if (_Port > 0) { temp += (":" + _Port); }
                    if (!String.IsNullOrEmpty(_InstanceName)) { temp += ("\\" + _InstanceName); }
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
                    string temp = _ComputerName;
                    if (_NetworkProtocol == SqlConnectionProtocol.NP) { temp = "NP:" + temp; }
                    if (_NetworkProtocol == SqlConnectionProtocol.TCP) { temp = "TCP:" + temp; }
                    if (_Port > 0) { return temp + "," + _Port; }
                    if (!String.IsNullOrEmpty(_InstanceName)) { return temp + "\\" + _InstanceName; }
                    return temp;
                }
            }

            /// <summary>
            /// Name of the computer as used in an SQL Statement
            /// </summary>
            [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
            public string SqlComputerName
            {
                get { return "[" + _ComputerName + "]"; }
            }

            /// <summary>
            /// Name of the instance as used in an SQL Statement
            /// </summary>
            [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
            public string SqlInstanceName
            {
                get
                {
                    if (String.IsNullOrEmpty(_InstanceName))
                        return "[MSSQLSERVER]";
                    else { return "[" + _InstanceName + "]"; }
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
                    if (String.IsNullOrEmpty(_InstanceName)) { return "[" + _ComputerName + "]"; }
                    else { return "[" + _ComputerName + "\\" + _InstanceName + "]"; }
                }
            }

            /// <summary>
            /// The original object passed to the parameter class.
            /// </summary>
            [ParameterContract(ParameterContractType.Field, ParameterContractBehavior.Mandatory)]
            public object InputObject;
            #endregion Fields of contract

            private string _ComputerName;
            private string _InstanceName;
            private int _Port;
            private SqlConnectionProtocol _NetworkProtocol = SqlConnectionProtocol.Any;

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
            /// <param name="Input">The parameter class object to convert</param>
            [ParameterContract(ParameterContractType.Operator, ParameterContractBehavior.Conversion)]
            public static implicit operator string(DbaInstanceParameter Input)
            {
                return Input.FullName;
            }

            #region Constructors
            /// <summary>
            /// Creates a DBA Instance Parameter from string
            /// </summary>
            /// <param name="Name">The name of the instance</param>
            public DbaInstanceParameter(string Name)
            {
                InputObject = Name;

                if (Name == ".")
                {
                    _ComputerName = Name;
                    _NetworkProtocol = SqlConnectionProtocol.NP;
                    return;
                }

                string tempString = Name;

                // Handle and clear protocols. Otherwise it'd make port detection unneccessarily messy
                if (Regex.IsMatch(tempString, "^TCP:", RegexOptions.IgnoreCase))
                {
                    _NetworkProtocol = SqlConnectionProtocol.TCP;
                    tempString = tempString.Substring(4);
                }
                if (Regex.IsMatch(tempString, "^NP:", RegexOptions.IgnoreCase))
                {
                    _NetworkProtocol = SqlConnectionProtocol.NP;
                    tempString = tempString.Substring(3);
                }

                // Case: Default instance | Instance by port
                if (tempString.Split('\\').Length == 1)
                {
                    if (Regex.IsMatch(tempString, @"[:,]\d{1,5}$") && !Regex.IsMatch(tempString, Utility.RegexHelper.IPv6) && ((tempString.Split(':').Length == 2) || (tempString.Split(',').Length == 2)))
                    {
                        char delimiter;
                        if (Regex.IsMatch(tempString, @"[:]\d{1,5}$"))
                            delimiter = ':';
                        else
                            delimiter = ',';

                        try
                        {
                            Int32.TryParse(tempString.Split(delimiter)[1], out _Port);
                            if (_Port > 65535) { throw new PSArgumentException("Failed to parse instance name: " + tempString); }
                            tempString = tempString.Split(delimiter)[0];
                        }
                        catch
                        {
                            throw new PSArgumentException("Failed to parse instance name: " + Name);
                        }
                    }

                    if (Utility.Validation.IsValidComputerTarget(tempString))
                    {
                        _ComputerName = tempString;
                    }

                    else
                    {
                        throw new PSArgumentException("Failed to parse instance name: " + Name);
                    }
                }

                // Case: Named instance
                else if (Name.Split('\\').Length == 2)
                {
                    string tempComputerName = Name.Split('\\')[0];
                    string tempInstanceName = Name.Split('\\')[1];

                    if (Regex.IsMatch(tempComputerName, @"[:,]\d{1,5}$") && !Regex.IsMatch(tempComputerName, Utility.RegexHelper.IPv6))
                    {
                        throw new PSArgumentException("Both port and instancename detected! This is redundant and bad practice, specify only one: " + Name);
                    }

                    if (Utility.Validation.IsValidComputerTarget(tempComputerName) && Utility.Validation.IsValidInstanceName(tempInstanceName))
                    {
                        _ComputerName = tempComputerName;
                        _InstanceName = tempInstanceName;
                    }

                    else
                    {
                        throw new PSArgumentException("Failed to parse instance name: " + Name);
                    }
                }

                // Case: Bad input
                else { throw new PSArgumentException("Failed to parse instance name: " + Name); }
            }

            /// <summary>
            /// Creates a DBA Instance Parameter from an IPAddress
            /// </summary>
            /// <param name="Address"></param>
            public DbaInstanceParameter(System.Net.IPAddress Address)
            {
                _ComputerName = Address.ToString();
            }

            /// <summary>
            /// Creates a DBA Instance Parameter from the reply to a ping
            /// </summary>
            /// <param name="Ping">The result of a ping</param>
            public DbaInstanceParameter(System.Net.NetworkInformation.PingReply Ping)
            {
                _ComputerName = Ping.Address.ToString();
            }

            /// <summary>
            /// Creates a DBA Instance Parameter from the result of a dns resolution
            /// </summary>
            /// <param name="Entry">The result of a dns resolution, to be used for targetting the default instance</param>
            public DbaInstanceParameter(System.Net.IPHostEntry Entry)
            {
                _ComputerName = Entry.HostName;
            }

            /// <summary>
            /// Creates a DBA Instance parameter from any object
            /// </summary>
            /// <param name="Input">Object to parse</param>
            public DbaInstanceParameter(object Input)
            {
                InputObject = Input;
                PSObject tempInput = new PSObject(Input);
                string typeName = "";

                try { typeName = tempInput.TypeNames[0].ToLower(); }
                catch
                {
                    throw new PSArgumentException("Failed to interpret input as Instance: " + Input.ToString());
                }

                typeName = typeName.Replace("Deserialized.", "");

                switch (typeName)
                {
                    case "microsoft.sqlserver.management.smo.server":
                        try
                        {
                            _ComputerName = (string)tempInput.Properties["NetName"].Value;
                            _InstanceName = (string)tempInput.Properties["InstanceName"].Value;
                            PSObject tempObject = new PSObject(tempInput.Properties["ConnectionContext"].Value);

                            string tempConnectionString = (string)tempObject.Properties["ConnectionString"].Value;
                            tempConnectionString = tempConnectionString.Split(';')[0].Split('=')[1].Trim().Replace(" ", "");

                            if (Regex.IsMatch(tempConnectionString, @",\d{1,5}$") && (tempConnectionString.Split(',').Length == 2))
                            {
                                try { Int32.TryParse(tempConnectionString.Split(',')[1], out _Port); }
                                catch (Exception e)
                                {
                                    throw new PSArgumentException("Failed to parse port number on connection string: " + tempConnectionString, e);
                                }
                                if (_Port > 65535) { throw new PSArgumentException("Failed to parse port number on connection string: " + tempConnectionString); }
                            }
                        }
                        catch (Exception e)
                        {
                            throw new PSArgumentException("Failed to interpret input as Instance: " + Input.ToString() + " : " + e.Message, e);
                        }
                        break;
                    case "microsoft.sqlserver.management.smo.linkedserver":
                        try
                        {
                            _ComputerName = (string)tempInput.Properties["Name"].Value;
                        }
                        catch (Exception e)
                        {
                            throw new PSArgumentException("Failed to interpret input as Instance: " + Input.ToString(), e);
                        }
                        break;
                    case "microsoft.activedirectory.management.adcomputer":
                        try
                        {
                            _ComputerName = (string)tempInput.Properties["Name"].Value;

                            // We prefer using the dnshostname whenever possible
                            if (tempInput.Properties["DNSHostName"].Value != null)
                            {
                                if (!String.IsNullOrEmpty((string)tempInput.Properties["DNSHostName"].Value))
                                    _ComputerName = (string)tempInput.Properties["DNSHostName"].Value;
                            }
                        }
                        catch (Exception e)
                        {
                            throw new PSArgumentException("Failed to interpret input as Instance: " + Input.ToString(), e);
                        }
                        break;
                    default:
                        throw new PSArgumentException("Failed to interpret input as Instance: " + Input.ToString());
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
}