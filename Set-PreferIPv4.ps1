<#
.SYNOPSIS
  Sets prefix policy to prefer IPv4 over IPv6.

.DESCRIPTION
  Sets prefix policy to prefer IPv4 over IPv6.

.NOTES
  Version:        1.0
  Author:         Mike McGhee
  Creation Date:  08/28/2017
  Purpose/Change: Initial script commit

.EXAMPLE
  Basic usage

  .\Set-PreferIPv4.ps1
#>

$prefixList = @(
    @{
        Name       = '3ffe::/16'
        Precedence = 1
        Label      = 12
    }
    @{
        Name       = 'fec0::/10'
        Precedence = 1
        Label      = 11
    }
    @{
        Name       = '::/96'
        Precedence = 1
        Label      = 4
    }
    @{
        Name       = 'fc00::/7'
        Precedence = 3
        Label      = 13
    }
    @{
        Name       = '2001::/32'
        Precedence = 5
        Label      = 5
    }
    @{
        Name       = '2002::/16'
        Precedence = 20
        Label      = 3
    }
    @{
        Name       = '::/0'
        Precedence = 30
        Label      = 2
    }
    @{
        Name       = '::1/128'
        Precedence = 40
        Label      = 1
    }
    @{
        Name       = '::ffff:0:0/96'
        Precedence = 50
        Label      = 0
    }
)

try
{
    if ((Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' | Select-Object -ExpandProperty 'DisabledComponents') -eq 32)
    {
        Write-Output "Prefix policy setting exists in Registry."
    }
    else
    {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\" -Name "DisabledComponents" -Value 0x20
        Write-Output "Prefix policy setting created in Registry."
    }
}
catch
{
    New-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\" -Name "DisabledComponents" -Value 0x20 -PropertyType "DWord"
    Write-Output "Prefix policy setting created in Registry."
}

$pingtest = Test-NetConnection localhost

if ($pingtest.RemoteAddress -eq '::1')
{
    Write-Output "Prefix policy is not active. Setting now..."
    foreach ($prefix in $prefixList)
    {
        & netsh interface ipv6 set prefixpolicy $prefix.Name $prefix.Precedence $prefix.Label
    }
    Write-Output "Prefix policy set to active."
}
else
{
    Write-Output "Prefix policy is already active."
}

