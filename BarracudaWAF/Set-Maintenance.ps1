<#
.SYNOPSIS
  Set maintenance mode on server.

.DESCRIPTION
  Connects to Barracuda WAF, searches for all instances of specified server and modifies current mode.

.NOTES
  Version:        1.0
  Author:         Mike McGhee
  Date:           03/22/2018
  Purpose/Change: Initial commit

.PARAMETER waf
 FQDN of WAF to connect to. 

.PARAMETER credential
 Barracuda WAF API credentials

.PARAMETER serverIP
 IP address of server to modify

 .PARAMETER mode
 Mode to set. Valid options are "In Service", "Out of Service Maintenance", "Out of Service Sticky", "Out of Service All"

.EXAMPLE
  .\Set-Maintenance.ps1 -waf "waf.contoso.com" -credential $creds -serverIP "192.168.1.2" -mode "Out of Service Maintenance"

#>

Param(
    [parameter(Mandatory = $true)] 
    $waf,
    [Parameter(Mandatory = $true)]
    [System.Management.Automation.PSCredential]$credential,
    [parameter(Mandatory = $true)]
    $serverIP,
    [parameter(Mandatory = $true)]
    [ValidateSet("In Service", "Out of Service Maintenance", "Out of Service Sticky", "Out of Service All")] $mode
)

function Connect-WAF
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [string[]]$waf,
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.PSCredential]$credential
    )
    # Set PowerShell to use TLS 1.2
    if ([System.Net.ServicePointManager]::CertificatePolicy.ToString() -eq "TrustAllCertsPolicy")
    {
        Write-Verbose "Current policy is already set to TrustAllCertsPolicy"
    }
    else
    {
        add-type -ErrorAction SilentlyContinue @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Full WAF rest api URL
    $wafUrl = "https://$waf/restapi/v3"

    # Get Creds
    $credHeader = $credential.GetNetworkCredential()

    # Body for auth token request
    $authBody = @{}
    $authBody.Add("username", $credHeader.UserName)
    $authBody.Add("password", $credHeader.Password)

    # Rest api login URI
    $uri = $wafUrl + "/login"

    # Request auth token
    $result = Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Body (ConvertTo-Json $authBody)

    If ($result.error)
    {
        Throw $result.error.description
    }
    ElseIf ($result.token)
    {
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(($result.token + ":")))
        $base64Header = @{Authorization = "Basic " + $base64AuthInfo}
        $header = $base64Header
        Return  @{header = $header; token = $result.token; url = $waf} 
    }
}

function Disconnect-WAF
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [string[]]$waf
    )
    $Result = $null
    Try
    {
        $path = $waf.url + "/logout"
        $result = Invoke-RestMethod -Uri $path -Method DELETE -ContentType 'application/json' -Headers $waf.header -Body ''
        $waf.token = ''
    }
    Catch
    {
        Write-Output "Logout: An error occurred while logging out."
    }
    Return $result.msg
}

function Invoke-GetRequest 
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        $waf,
        [Parameter(Mandatory = $True)]
        [string[]]$path
    )
    Try
    {
        $url = "https://" + $waf.url + "/restapi/v3/" + $path
        $request = Invoke-RestMethod $url -Headers $waf.header
        $result = @{}
        $request.data.psobject.properties | ForEach-Object { $result[$_.Name] = $_.Value }
    }
	Catch
    {
        Write-Output "Invoke-GetRequest: An error occurred while getting value."
    }
    return $result
}

Function Invoke-PutRequest
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        $waf,
        [Parameter(Mandatory = $True)]
        [string[]]$path,
        [Parameter(Mandatory = $True)]
        $data
    )
    Try
    {
        $body = $data | ConvertTo-Json
        $url = "https://" + $waf.url + "/restapi/v3/" + $path
        $result = Invoke-RestMethod $url -Headers $waf.header -Method PUT -Body $body -ContentType 'application/json'
    }
    Catch
    {
        Write-Output "Invoke-PutRequest: An error occurred while setting value."
    }
    return $result.msg
}

Function Set-MaintenanceMode
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        $waf,
        [parameter(Mandatory = $true)] 
        $serverIP,
        [parameter(Mandatory = $true)]
        [ValidateSet("In Service", "Out of Service Maintenance", "Out of Service Sticky", "Out of Service All")]
        $mode
    )
    # Get all services
    $path = "services"
    $services = Invoke-GetRequest -waf $waf -path $path
    foreach ($service in $services.Keys)
    {
        Write-Host "Inspecting virtual service"$service"..."
        # Get all servers
        $servicePath = "services/" + $service + "/servers"
        $servers = Invoke-GetRequest -waf $waf -path $servicePath

        # Iterate over servers
        foreach ($serverKey in $servers.Keys)
        {
            $server = $servers[$serverKey]
            if ($server.'ip-address' -eq $serverIP)
            {
                Write-Host "  Found server "$server.'ip-address'" (currently in mode "$server.status"), changing mode..."
                $update = @{status = $mode}
                $serverPath = $servicePath + "/" + $server.name
                Try
                {
                    $result = Invoke-PutRequest -waf $waf -path $serverPath -data $update
                    Write-Host "    "$result.msg
                }
                Catch
                {
                    Write-Output "Set-MaintenanceMode: An error occurred while setting value."
                }
            }
        }
    }
}


$waf = Connect-WAF -waf $waf -credential $credential
Set-MaintenanceMode -waf $waf -serverIP $serverIP -mode $mode
Disconnect-WAF -waf $waf
