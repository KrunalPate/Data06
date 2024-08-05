##############################################################################
#.SYNOPSIS
# Helper functions to query AMIs, I/O etc
#
#.DESCRIPTION
# Helper routines include querying SUSE AMI per region, Taking snapshot
# Parsing input HANA password as secure string etc
##############################################################################


# Get the latest SUSE ami (x86_64). Pick top one when multiple amis exist



Function GetLatestSUSEamiFromTable
{
	Param(
	  [Parameter(Mandatory=$True)]
	  [string]$region
	  )

	$hvmAMI= @{ 	"us-east-1"="ami-70f74418";
			"us-west-2"="ami-3b0f420b";
			"us-west-1"="ami-cbe3e88e";
			"eu-west-1"="ami-30842747";
			"ap-southeast-1"="ami-a4bd9af6";
			"ap-northeast-1"="ami-69012b68";
			"ap-southeast-2"="ami-41a5c77b";
			"sa-east-1"="ami-ef8134f2";
			"eu-central-1" ="ami-423e085f";
		}

	  return $hvmAMI.Get_Item($region)
}


Function GetLatestSUSEami
{
	Param(
	  [Parameter(Mandatory=$True)]
	  [string]$region
	  )
	$ChooseServicePack3 = $true

	$os_filter = New-Object Amazon.EC2.Model.Filter
	$os_filter.Name = "description"
	if ($ChooseServicePack3 -eq $True) {
		$os_filter.Value.Add("*SUSE*Service Pack 3*")
	} else {
		$os_filter.Value.Add("*SUSE*")
	}

	$arch_filter = New-Object Amazon.EC2.Model.Filter
	$arch_filter.Name = "architecture"
	$arch_filter.Value.Add("*x86_64*")

	$name_filter = New-Object Amazon.EC2.Model.Filter
	$name_filter.Name = "name"
	$name_filter.Value.Add("*suse*hvm*")

	$status_filter = New-Object Amazon.EC2.Model.Filter
	$status_filter.Name = "state"
	$status_filter.Value.Add("available")

	$ami = Get-EC2Image -Owner amazon, self `
						 -Filter $os_filter, $arch_filter, $name_filter, $status_filter `
						-Region $region | select ImageId | sort

	return $ami[0].ImageId

}

# Takes Snapshot of D:\. Will wait until snapshot is complete
# TODO: Check if D:\ is being used by some other program.

Function GetSAPMediaSnapshot {
	Param(
	  [Parameter(Mandatory=$True)]
	  [string]$volume,
	
	  [Parameter(Mandatory=$True)]
	  [string]$region
	)

	while ($true) { 
		if (gci D:\ -rec -filter *DATA_UNITS*  |  where {$_.psiscontainer } | gci)  { 
			Write-Host "   Verified DATA_UNITS directory exists in D:\" 
			Write-Host "" 
			break 
		} else {
			Write-Host "   Unable to find DATA_UNITS directory exists in D:\. Did download complete ? " 
			Write-Host "   Download SAP Media into D:\" 
			Write-Host "   Press any key AFTER download is complete ..." 
			$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 
		} 
	}
	Write-Host "   Bringing disk 1 offline before taking snapshot.." 
	"Select disk 1","offline disk","exit" | diskpart | Out-Null  
	$snapshot = New-EC2Snapshot  -volumeid $volume -Region $region -Description "SAP Media Snapshot" 
	$status = Get-EC2Snapshot -SnapshotId  $snapshot.SnapshotId -Region $region
	while ($status.Status -ne "completed") {
		Write-Host "   Snapshot Status Pending (Total estimated time 10-15 minutes)." 
		Start-Sleep 10 
		$status = Get-EC2Snapshot -SnapshotId  $snapshot.SnapshotId -Region $region
	}
	Write-Host "   Bringing disk 1 online.." 
	$SnapshotId  = $snapshot.SnapshotId
	Write-Host "   $SnapshotId : SAP Media Snapshot Status Complete!" 
	"Select disk 1","online disk","exit" | diskpart | Out-Null  

	return 	$SnapshotId
}

Function PrintIntro
{

	Write-Host ""
	Write-Host ""
	Write-Host ""
	Write-Host ""
	Write-Host "   This Powershell script will deploy SAP HANA into AWS."
	Write-Host "   Cloudformation template files are located in the Generic directory. "
	Write-Host "   A snapshot of HANA media downloaded in D:\ will be taken and the HANA hosts will be installed with this media. "
	Write-Host ""
	Write-Host ""

}



Function ReadInt
{
	Param([string] $Tag = "Enter Integer",
		  [int] $Min,
		  [int] $Max,
		  [int] $default
		  )
	Try {
		$val = read-host "   $Tag"
	}
	Catch  [system.exception] {
		Write-Host "   Exception: Expected value [$Min,$Max]"
		$val = $default 
	} 

	if ($val  -lt $Min -or $val  -gt $Max )
	{
		Write-Host "   Expected value [$Min,$Max]"
		$val = $default 
	}
	
	$val
}

Function IsValidPasswordUnused{

    param(
        [string] $Password = $(throw "Please Specify HANA Password"),
        [int] $MinLength = 8,
        [int] $NumUpper = 0,
        [int] $NumLower = 0,
        [int] $NumNumbers = 0, 
        [int] $NumSpecial = 0
    )


    $upper = [regex]"[A-Z]"
    $lower = [regex]"[a-z]"
    $number = [regex]"[0-9]"
    #Special is "none of the above"
    $special = [regex]"[^a-zA-Z0-9]"

    # Check the length.
    if($pwd.length -lt $minLength) {$false; return}

    # Check for minimum number of occurrences.
    if($upper.Matches($pwd).Count -lt $NumUpper ) {$false; return}
    if($lower.Matches($pwd).Count -lt $NumLower ) {$false; return}
    if($number.Matches($pwd).Count -lt $NumNumbers ) {$false; return}
    if($special.Matches($pwd).Count -lt $NumSpecial ) {$false; return}

    # Passed all checks.
    $true
}

Function GetAmazonCFParameter($Key,$Value) {
	$pObj = @{ ParameterKey=$Key; ParameterValue= $Value  }
	$pObj
}


Function ReadHANAPassword
{
	$PassRegex =  "^(?=.*?[a-z])(?=.*?[A-Z])(?=.*[0-9]).*$"
	$HANAMasterPassSecure = Read-Host '   Enter HANA Master password' -AsSecureString
	$HANAMasterPass = `
			[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($HANAMasterPassSecure))

	while ($true) {
		if ($HANAMasterPass -match  $PassRegex) {
			break
		} else {
			Write-Host "   HANA password must be a minimum of 8 characters (upper/lower case and numeric allowed)"
			$HANAMasterPassSecure = Read-Host '   Enter HANA Master password' -AsSecureString
			$HANAMasterPass = `
					[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($HANAMasterPassSecure))
		}
	}

	$HANAMasterPass
	
}
