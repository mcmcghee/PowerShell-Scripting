<#
.SYNOPSIS
  Configures logging to Azure.

.DESCRIPTION
  Configures the Microsoft Monitoring Agent to send logs to an Azure Log Analytics (OMS) workspace. Optionally configures a proxy url.

.NOTES
  Version:        1.0
  Author:         Mike McGhee
  Date:           04/09/2018
  Purpose/Change: Initial commit

  Built from example on Microsoft Docs: https://docs.microsoft.com/et-EE/azure/log-analytics/log-analytics-agent-manage

.PARAMETER proxyUrl
 Optional proxy url.

.PARAMETER workspaceId

.PARAMETER workspaceKey

.EXAMPLE
Configure machine for a proxy and connect to Azure.
  .\Set-ATPWorkspace.ps1 -proxyUrl "proxy.contoso.com:8080" -workspaceId "XXXXXXXXXXXXXXXXX" -workspaceKey "XXXXXXXXXXXXX"

#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    $proxyUrl,
    [Parameter(Mandatory = $true)]
    $workspaceId,
    [Parameter(Mandatory = $true)]
    $workspaceKey
)

$healthServiceSettings = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'

if ($proxyUrl)
{
    $proxyMethod = $healthServiceSettings | Get-Member -Name 'SetProxyInfo'

    if (!$proxyMethod)
    {
        Write-Output 'Health Service proxy API not present, will not update settings.'
        return
    }

    Write-Output "Clearing proxy settings."
    $healthServiceSettings.SetProxyInfo('', '', '')

    Write-Output "Setting proxy to $proxyUrl."
    $healthServiceSettings.SetProxyUrl($proxyUrl)
}
else
{
    Write-Output "Proxy not set. Skipping."
}

Write-Output "Checking Cloud Workspace."
if ($healthServiceSettings.GetCloudWorkspace($workspaceId))
{
    Write-Output "Workspace exists. Updating key."
    $c = $healthServiceSettings.GetCloudWorkspace($workspaceId)
    $c.UpdateWorkspaceKey($workspaceKey)
}
else
{
    Write-Output "Adding Cloud Workspace."
    $healthServiceSettings.AddCloudWorkspace($workspaceId, $workspaceKey, 0)
}

$healthServiceSettings.EnableActiveDirectoryIntegration()

Write-Output "Reloading configuration."
$healthServiceSettings.ReloadConfiguration()
Get-Service HealthService | Restart-Service