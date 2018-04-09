<#
.SYNOPSIS
  Installs and registers OSSEC agent with OSSEC server.

.DESCRIPTION
  Input servers and keys into $servers hash table, specify the $source of the executable, and run.

.NOTES
  Version:        1.0
  Author:         Mike McGhee
  Creation Date:  05/02/2017
  Purpose/Change: Initial script development

  Inspiration from: https://groups.google.com/d/msg/ossec-list/XpOvdGRlsc8/In_k6oSyDAAJ

.EXAMPLE
  Basic usage

  .\Install-OSSEC-Agent.ps1

#>

$servers = @{
    'server1' = 'key'
    'server2' = 'key'
}

$ossecServerIP = "192.168.1.1"

$installFile = "\\server\share\ossec-agent-win32-2.8.3.exe"

$ScriptBlockContent = {
    $key = $args[0]

    #================== Install OSSEC ==================
    $install = "C:\Program Files\ossec-agent-win32-2.8.3.exe"
    $installparam = "/S"

    & $install $installparam

    Start-Sleep -s 10

    #================== Register w/ Key ==================
    $exe = "C:\Program Files (x86)\ossec-agent\manage_agents.exe"
    $param1 = "-i"
        
    Write-Output "Y`r" | & $exe $param1 $key
    
    #================== Set Server IP in Config ==================
    $ossec_config_file = "${env:ProgramFiles(x86)}\ossec-agent\ossec.conf"
    [xml]$xml = "<fake>$(Get-Content $ossec_config_file)</fake>"

    foreach ($ossec_config in $xml.fake.SelectNodes('//ossec_config'))
    {
        $clients = $ossec_config.SelectNodes('client')
        if ($clients.Count -eq 0)
        {
            $client = $ossec_config.AppendChild($xml.CreateElement('client'))
            $clients = $ossec_config.SelectNodes('client')
        }
        foreach ($client in $clients)
        {
            $server_ips = $client.SelectNodes('server-ip')
            if ($server_ips.Count -eq 0)
            {
                $server_ip = $client.AppendChild($xml.CreateElement('server-ip'))
                $server_ips = $client.SelectNodes('server-ip')
            }
            foreach ($server_ip in $server_ips)
            {
                $server_ip.set_InnerText($ossecServerIP)
            }
        }
        $xml2 = New-Object System.Xml.XmlDocument
        $node = $xml2.AppendChild($xml2.ImportNode($ossec_config, $true))
        $xml2.Save($ossec_config_file)
    }

    #================== Start OSSEC Service ==================
    get-service OssecSvc | restart-service
}

$servers.GetEnumerator() | ForEach-Object {
    $computer = $_.Key
    $key = $_.Value

    Copy-Item $installFile -destination "\\$computer\c$\Program Files\"
    Invoke-Command -ComputerName $computer -ScriptBlock $ScriptBlockContent -ArgumentList $key
}
