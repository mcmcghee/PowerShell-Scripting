<#
.SYNOPSIS
  Purge an Office 365 mailbox

.DESCRIPTION
  Connects to Office 365, deletes all items in a mailbox.

.NOTES
  Version:        1.0
  Author:         Mike McGhee
  Date:           02/2/2018
  Purpose/Change: Initial commit

  This script runs in an inifinite loop in case the connection dies. This means you will need to manually stop it.

.PARAMETER mailbox
 Mailbox to purge items from

.PARAMETER credential
 Office 365 admin creds

.EXAMPLE
  .\Delete-AllItems.ps1 -mailbox "user@contoso.com" -credential $creds

#>

Param(
    [parameter(Mandatory = $true)] 
    $mailbox,
    [Parameter(Mandatory = $true)]
    [System.Management.Automation.PSCredential]$credential
)

$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $credential -Authentication Basic -AllowRedirection
Import-PSSession $session

try
{
    while ($true)
    {   
        Search-Mailbox -Identity $mailbox -DeleteContent -Force -Verbose
    }
}
finally
{
    Remove-Session $session
}
