#======================================================================================================================
#
# Script purpose : Collect Intune Device event logs, files and folders, registry keys and upload them on Sharepoint
# Author 		 : Damien VAN ROBAEYS
# Twitter 		 : @syst_and_deploy
# Blog 		     : http://www.systanddeploy.com/
#
#======================================================================================================================

# ##########################################################################################
# Use this part if you have an external XML for content to collect
# ##########################################################################################

$Current_Folder = split-path $MyInvocation.MyCommand.Path
# $Content_to_collect_File = "$Current_Folder\Content_to_collect.xml"
# $Content_to_collect_File = "XML Path\Content_to_collect.xml"


# ##########################################################################################
# Use this part if you want to convert the XML to base64 in order to have a single PS1 file
# ##########################################################################################

# Code to convert the XML to base64
# $XML_Path = "C:\Users\damien.vanrobaeys\OneDrive - METSYS\Desktop\Intune_troubleshooting\Content_to_collect.xml"
# $Base64_Code = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes("$XML_Path"));		

# Convert from Base64 to XML
$XML_Base64 = ""
$XML_Path = "$Current_Folder\Content_to_collect.xml"
[byte[]]$Bytes = [convert]::FromBase64String($XML_Base64)
[System.IO.File]::WriteAllBytes($XML_Path,$Bytes)


# ##########################################################################################
# Use this part if you have an external XML for content to collect
# ##########################################################################################
$Sharepoint_Secret = '<Type the sharepoint app secret>'
$Sharepoint_ClientID = "<Type the sharepoint app client id>"
$Site_URL = "<Type the URL of the Sharepoint site>" 
$Upload_Folder = "<Type the path where to upload content>"


# ##########################################################################################
# Main variables
# ##########################################################################################	

$SystemRoot = $env:SystemRoot
$CompName = $env:computername

$Get_Day_Date = Get-Date -Format "yyyyMMdd"
$Log_File = "$SystemRoot\Debug\Collect_Device_Content_$CompName" + "_$Get_Day_Date.log"
$Logs_Collect_Folder = "C:\Device_Logs_From" + "_$CompName" + "_$Get_Day_Date"
$Logs_Collect_Folder_ZIP = "$Logs_Collect_Folder" + ".zip"
$EVTX_files = "$Logs_Collect_Folder\EVTX_Files"
$Reg_Export = "$Logs_Collect_Folder\Export_Reg_Values.csv"
$Logs_Folder = "$Logs_Collect_Folder\All_logs"

$Content_to_collect_XML = [xml] (Get-Content $XML_Path)

If(!(test-path $Logs_Collect_Folder)){new-item $Logs_Collect_Folder -type Directory -force | out-null}
If(!(test-path $EVTX_files)){new-item $EVTX_files -type Directory -force | out-null}
If(!(test-path $Log_File)){new-item $Log_File -type file -force | out-null}
If(!(test-path $Logs_Folder)){new-item $Logs_Folder -type Directory -force | out-null}


# ##########################################################################################
# Main functions
# ##########################################################################################	

Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"	
		# write-host "$MyDate - $Message_Type : $Message"	
	}
	
Function Export_Event_Logs
	{
		param(
		$Log_To_Export,	
		$Log_Output,
		$File_Name
		)	
		
		Write_Log -Message_Type "INFO" -Message "Collecting logs from: $Log_To_Export"
		Try
			{
				WEVTUtil export-log $Log_To_Export "$Log_Output\$File_Name.evtx" | out-null	
				Write_Log -Message_Type "SUCCESS" -Message "Event log $File_Name.evtx has been successfully exported"
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "An issue occured while exporting event log $File_Name.evtx"
			}
	}	
	
	
Function Export_Logs_Files_Folders
	{
		param(
		$Log_To_Export,	
		$Log_Output
		)	
		
		If(test-path $Log_To_Export)
			{
				$Content_Name = Get-Item $Log_To_Export
				Try
					{
						Copy-Item $Log_To_Export $Log_Output -Recurse -Force
						Write_Log -Message_Type "SUCCESS" -Message "The folder $Content_Name has been successfully copied"													
					}
				Catch
					{
						Write_Log -Message_Type "ERROR" -Message "An issue occured while copying the folder $Content_Name"																				
					}
			}
		Else
			{
				Write_Log -Message_Type "ERROR" -Message "The following path does not exist: $Log_To_Export"			
			}
	}	
	
	
Function Export_Registry_Values
	{
		param(
		$Reg_Path,	
		$Reg_Specific_Value,
		$Output_Path
		)	
		
		If(test-path "registry::$Reg_Path")
			{					
				$Reg_Array = @()
				$Get_Reg_Values = Get-ItemProperty -path registry::$Reg_Path
				If($Reg_Specific_Value)
					{
						$List_Values = $Get_Reg_Values.$Reg_Specific_Value
						$Get_Reg_Values_Array = New-Object PSObject
						$Get_Reg_Values_Array = $Get_Reg_Values_Array | Add-Member NoteProperty Name $Reg_Specific_Value -passthru
						$Get_Reg_Values_Array = $Get_Reg_Values_Array | Add-Member NoteProperty Value $List_Values -passthru
						$Get_Reg_Values_Array = $Get_Reg_Values_Array | Add-Member NoteProperty Reg_Path $Reg_Path -passthru
					}
				Else	
					{
						$List_Values = $Get_Reg_Values.psobject.properties | select name, value | Where-Object {($_.name -ne "PSPath" -and $_.name -ne "PSParentPath" -and $_.name -ne "PSChildName" -and $_.name -ne "PSProvider")}
						$Get_Reg_Values_Array = New-Object PSObject
						$Get_Reg_Values_Array = $List_Values
						$Get_Reg_Values_Array = $Get_Reg_Values_Array | Add-Member NoteProperty Reg_Path $Reg_Path -passthru
					}
				
				$Reg_Array += $Get_Reg_Values_Array
				
				If(!(test-path $Output_Path))
					{			
						Try
							{
								$Reg_Array | export-csv $Output_Path  -notype
								Write_Log -Message_Type "SUCCESS" -Message "Registry values from $Reg_Path have been successfully exported"													
							}
						Catch
							{
								Write_Log -Message_Type "ERROR" -Message "An issue occured while exporting registry values from $Reg_Path"																				
							}					
					}
				Else
					{
						Try
							{
								$Reg_Array | export-csv -Append $Output_Path  -notype
								Write_Log -Message_Type "SUCCESS" -Message "Registry values from $Reg_Path have been successfully exported"													
							}
						Catch
							{
								Write_Log -Message_Type "ERROR" -Message "An issue occured while exporting registry values from $Reg_Path"																				
							}															
					}					
			}
		Else
			{
				Write_Log -Message_Type "ERROR" -Message "The following REG path does not exist: $Reg_Path"			
			}
	}	



# ##########################################################################################
# Main code
# ##########################################################################################	

Write_Log -Message_Type "INFO" -Message "Starting collecting Intune logs on $CompName"

Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 1 - Collecting event logs"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"	
$Events_To_Check = $Content_to_collect_XML.Content_to_collect.Event_Logs.Event_Log
ForEach($Event in $Events_To_Check)
	{
		$Event_Name = $Event.Event_Name
		$Event_Path = $Event.Event_Path	
		Export_Event_Logs -Log_To_Export $Event_Path -Log_Output $EVTX_files -File_Name $Event_Name		
	}
	
	
Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 2 - Copying files and folders"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"	
$Folder_To_Check = $Content_to_collect_XML.Content_to_collect.Folders.Folder_Path
ForEach($Explorer_Content in $Folder_To_Check)
	{		
		Export_Logs_Files_Folders -Log_To_Export $Explorer_Content -Log_Output $Logs_Folder		
	}	
	

Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 3 - Collecting registry keys"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"	
$Reg_Keys_To_Check = $Content_to_collect_XML.Content_to_collect.Reg_Keys.Reg_Key
ForEach($Reg in $Reg_Keys_To_Check)
	{
		$Get_Reg_Path = $Reg.Reg_Path
		$Get_Reg_Specific_Value = $Reg.Reg_Specific_Value	
		If($Get_Reg_Specific_Value -ne $null)
			{
				Export_Registry_Values -Reg_Path $Get_Reg_Path -Reg_Specific_Value $Get_Reg_Specific_Value -Output_Path $Reg_Export			
			}
		Else
			{
				Export_Registry_Values -Reg_Path $Get_Reg_Path -Output_Path $Reg_Export					
			}		
	}			


Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 4 - Creating the ZIP with logs"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Try
	{
		Add-Type -assembly "system.io.compression.filesystem"
		[io.compression.zipfile]::CreateFromDirectory($Logs_Collect_Folder, $Logs_Collect_Folder_ZIP) 
		Write_Log -Message_Type "SUCCESS" -Message "The ZIP file has been successfully created"	
		Write_Log -Message_Type "INFO" -Message "The ZIP is located in :$Logs_Collect_Folder_ZIP"				
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "An issue occured while creating the ZIP file"		
	}
 
 
Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 5 - Installing PnP module"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"

$Is_Nuget_Installed = $False     
If(!(Get-PackageProvider | where {$_.Name -eq "Nuget"}))
	{                                         
		Write_Log -Message_Type "SUCCESS" -Message "The package Nuget is not installed"                                                                          
		Try
		{
				Write_Log -Message_Type "SUCCESS" -Message "The package Nuget is being installed"                                                                             
				[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
				Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Force -Confirm:$False | out-null                                                                                                                 
				Write_Log -Message_Type "SUCCESS" -Message "The package Nuget has been successfully installed"              
				$Is_Nuget_Installed = $True                                                                                     
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "An issue occured while installing package Nuget"   
				Break
			}
	}Else{
		$Is_Nuget_Installed = $True      
		Write_Log -Message_Type "SUCCESS" -Message "The package Nuget is already installed"                                                                                                                                         
	}

If($Is_Nuget_Installed -eq $True)
	{
		$Script:PnP_Module_Status = $False
		$Module_Name = "PnP.PowerShell"
		If (!(Get-InstalledModule $Module_Name -ErrorAction silentlycontinue)) 				
		{ 
			Write_Log -Message_Type "INFO" -Message "The module $Module_Name has not been found"      
			Try
				{
					Write_Log -Message_Type "INFO" -Message "The module $Module_Name is being installed"                                                                                                           
					Install-Module $Module_Name -Force -Confirm:$False -ErrorAction SilentlyContinue | out-null   
					$Module_Version = (Get-Module $Module_Name -listavailable).version
					Write_Log -Message_Type "SUCCESS" -Message "The module $Module_Name has been installed"      
					Write_Log -Message_Type "INFO" -Message "$Module_Name version $Module_Version"   
					$PnP_Module_Status = $True								
				}
			Catch
				{
					Write_Log -Message_Type "ERROR" -Message "The module $Module_Name has not been installed"                                          
				}                                                                                                                                                                                                                    
		} 
		Else
		{
			Try
				{
					Write_Log -Message_Type "INFO" -Message "The module $Module_Name has been found"                                                                                                                                                                      
					Import-Module $Module_Name -Force -ErrorAction SilentlyContinue 
					$PnP_Module_Status = $True	
					Write_Log -Message_Type "INFO" -Message "The module $Module_Name has been imported"     
				}
			Catch
				{
					Write_Log -Message_Type "ERROR" -Message "The module $Module_Name has not been imported"            
				}                                                         
		}                                                       
	}

If($PnP_Module_Status -eq $True)
	{ 
		Add-content $Log_File ""
		Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
		Write_Log -Message_Type "INFO" -Message "Step 6 - Connecting to Sharepoint"
		Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
		Try
			{
				Connect-PnPOnline -Url $Site_URL -ClientID $Sharepoint_ClientID -ClientSecret $Sharepoint_Secret			
				Write_Log -Message_Type "SUCCESS" -Message "Authentification OK to Sharepoint"	
				$Sharepoint_Status = "OK"		
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "Authentification KO to Sharepoint"	
				$Sharepoint_Status = "KO"		
			}	 
	
		If($Sharepoint_Status -eq "OK")
			{
				Add-content $Log_File ""
				Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
				Write_Log -Message_Type "INFO" -Message "Step 7 - Uploading the ZIP to Sharepoint"
				Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
				Try
					{
						Add-PnPFile -Path $Logs_Collect_Folder_ZIP -Folder $Upload_Folder | out-null
						Write_Log -Message_Type "SUCCESS" -Message "The ZIP file has been correctly uploaded to Sharepoint"	
					}
				Catch
					{
						Write_Log -Message_Type "ERROR" -Message "An issue occured while uploading ZIP file"	
					}
			}							
	}

Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 8 - Removing temp collect folder and ZIP"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Try
	{
		Remove-Item $Logs_Collect_Folder -Recurse -Force | out-null
		Remove-Item $Logs_Collect_Folder_ZIP -Recurse -Force | out-null
		Write_Log -Message_Type "SUCCESS" -Message "The collect folders have been removed"	
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "An issue occured while removing log collect folder"	
	}		