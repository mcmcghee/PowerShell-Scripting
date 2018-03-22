<#
.SYNOPSIS
  Purge an Office 365 mailbox, starting at a certain date.

.DESCRIPTION
  Connects to Office 365, deletes all items in a mailbox. This script starts deleting emails on a certain day and loops until the current date.

.NOTES
  Version:        1.0
  Author:         Mike McGhee
  Date:           02/2/2018
  Purpose/Change: Initial commit

  This script runs until it reaches the current date.

.PARAMETER mailbox
 Mailbox to purge items from

.PARAMETER startDate
 Beginning date to start deleting items from. E.g. "1/13/2017"

.PARAMETER credential
 Office 365 admin creds

.EXAMPLE
  .\Delete-ByDateLoop.ps1 -mailbox "user@contoso.com" -startDate "1/13/2017" -credential $creds

#>

Param(
    [parameter(Mandatory = $true)] 
    $mailbox,
    [parameter(Mandatory = $true)] 
    $startDate,
    [Parameter(Mandatory = $true)]
    [System.Management.Automation.PSCredential]$credential
)

$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $credential -Authentication Basic -AllowRedirection
Import-PSSession $session

try
{
    $startDate = Get-Date -Date $startDate
    $endDate = (Get-Date).Date
    while ($startDate -ine $endDate )
    {  
        $date = (Get-Date $startDate).ToShortDateString()
        Write-Output "Executing date $date"
        $mb = Search-Mailbox -Identity $mailbox -SearchQuery "(Received:$date)" -DeleteContent -Force -Verbose
        Write-Output $mb | Format-List *
        if ($mb.ResultItemsCount -eq 0)
        {
            $startDate = ($startDate).AddDays(1)
        }
    }
}
finally
{
    Remove-Session $session
}
