$SystemRoot = $env:SystemRoot
$CompName = $env:computername
$Get_Day_Date = Get-Date -Format "yyyyMMdd"
$Log_File = "$SystemRoot\Debug\Collect_Intune_Logs_GitHub_$CompName" + "_$Get_Day_Date.log"

If(test-path $Log_File)
	{
		write-host "Log file has been found"
	}
