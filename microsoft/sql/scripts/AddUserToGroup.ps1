Param(
[Parameter(Mandatory=$True)]
[string]$ServerName,
[Parameter(Mandatory=$True)]
[string]$GroupName,
[Parameter(Mandatory=$True)]
[string]$DomainNetBIOSName,
[Parameter(Mandatory=$True)]
[string]$UserName
)$de = [ADSI]"WinNT://$ServerName/$GroupName,group"
$de.psbase.Invoke("Add",([ADSI]"WinNT://$DomainNetBIOSName/$UserName").path)
