# 1 - Create the certificate
$Intune_Cert = New-SelfSignedCertificate -CertStoreLocation "cert:\LocalMachine\My" `
  -Subject "CN=IntuneLogCert" `
  -KeySpec KeyExchange
$keyValue = [System.Convert]::ToBase64String($Intune_Cert.GetRawCertData())

# 2 - Connect to Azure
Connect-AZAccount # Then type your creds

# 3 - Create the app with the certificate
$sp = New-AzADServicePrincipal -DisplayName IntuneLogCert `
  -CertValue $keyValue `
  -EndDate $Intune_Cert.NotAfter `
  -StartDate $Intune_Cert.NotBefore
New-AzRoleAssignment -RoleDefinitionName Owner -ServicePrincipalName $sp.ApplicationId

# 4 - Export the certificate
$Certificate_PFX_Path = "Path of the pfx file\intune_cert.pfx" # Where to export the pfx
$Intune_Cert = Get-ChildItem -Path Cert:\LocalMachine\My\ | Where-Object {$_.Subject -match "IntuneLogCert"}
$PFX_PWD = "intune" | ConvertTo-SecureString -AsPlainText -Force
Export-PfxCertificate -Cert $Intune_Cert -FilePath $Certificate_PFX_Path -Password $PFX_PWD

# 5 - Export password to secure file
$Cert_PWD_File = "password secure file path\cert_import.txt"
[Byte[]] $Encrypt_key = (1..16)
$PFX_PWD = "intune" | ConvertTo-SecureString -AsPlainText -Force
$PFX_PWD | ConvertFrom-SecureString -key $Encrypt_key | Out-File $Cert_PWD_File

# 6 - Connect to Azure with cerificate
Connect-AzAccount -CertificateThumbprint $Thumbprint -ApplicationId $ApplicationId -Tenant $TenantId -ServicePrincipal

# 7 - Upload the ZIP file to Azure file
$folderPath="/"  
$ctx=(Get-AzStorageAccount -ResourceGroupName $Azure_resourceGroupName -Name $Azure_storageAccName).Context  
$fileShare=Get-AZStorageShare -Context $ctx -Name $Azure_fileShareName  
Set-AzStorageFileContent -Share $fileShare -Source $Logs_Collect_Folder_ZIP -Path $folderPath -Force 


# Import the certificate
$Certificate_PFX_Path = "your certificate path\intune_cert.pfx" 
[Byte[]] $Encrypt_key = (1..16)
$Cert_PWD_File = "password secure file path\cert_import.txt"
$secureString = Get-Content $Cert_PWD_File | ConvertTo-SecureString -Key $Encrypt_key
Import-PfxCertificate -FilePath $Certificate_PFX_Path -CertStoreLocation Cert:\CurrentUser\My -Password $secureString 
