##############################################################################
#.SYNOPSIS
# Script to deploy SAP HANA in AWS
#
#.DESCRIPTION
# This script uses the cloudformation template located in Generic directory.
# Depending on single host or multi-host installation, the correspoding templates are
# deployed in AWS. Input parameters such as HANA password, number of hosts, EBS volumes
# etc can be either specified as a command parameter or be prompted to be input.
#
#.PARAMETER TypeName
# Not supported, but provided to maintain consistency with New-Object.
#
#.EXAMPLE
# Show Some Usages
# get-help .\SAP_HANA_Deploy.ps1 -examples
#.EXAMPLE
# Deploy (Take inputs during launch)
#.\SAP_HANA_Deploy.ps1

##############################################################################

. '.\SAP_AWS_Helper.ps1'
. '.\CustomParameters.ps1'

[Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" ) | Out-Null

# Wait for HANA bits to be downloaded and deploy HANA in AWS


# defaults
$ifdebug = "true"
$default_hostcount = 1
$default_os_choice = "S"
$default_InstanceType = "r3.8xlarge"
$default_MediaDir = "D:\"

Function InstallHANAStudio {

	[CmdletBinding(PositionalBinding=$false)]
	Param( [String] $MediaDir= $default_MediaDir)

    $jreZipFile = "C:\Users\Administrator\SAP\JAVA\jre-7u7-win-x64.zip"
	$jreDest ="C:\Users\Administrator\SAP\JAVA"
	@($jreDest ) | Where-Object { Test-Path $_ } | ForEach-Object { Remove-Item $_ -Recurse -Force -ErrorAction Stop }
	New-Item -ItemType Directory -Force -Path $jreDest | Out-Null

	Write-Host "   Downloading JAVA before installing HANA Studio..."
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($jreURL, $jreZipFile)

	Write-Host "   Download complete. Extracting now..."
	$zipSrc = Get-Item ( $jreZipFile )
	[System.IO.Compression.ZipFile]::ExtractToDirectory($jreZipFile, $jreDest )


	if ((Test-Path $MediaDir) -eq 0) {
		Write-Host " MediaDir $MediaDir does not exist! Did you download SAP Media into $MediaDir ?"
		Write-Host " HANA Studio install failure!"
	} else {
	 $HDBRootDir = Get-ChildItem -Path $MediaDir -Filter HDB_STUDIO_WINDOWS_X86_64 -Recurse | % {$_.FullName}
	 $HDBInstallFile = "$HDBRootDir\hdbinst.exe"
	 if ((Test-Path $HDBInstallFile) -eq 0) {
		Write-Host " $HDBInstallFile does not exist!"
		Write-Host " HANA Studio install failure!"
	  }
	  else {
			$arg1 = "-b"
			$arg2 = '--path=' + '"' + "C:\Program Files\sap\hdbstudio" + '"'
			$arg3 = '--vm=' + '"' + $jreDest + "\jre7\bin\javaw.exe" + '"'
			[Array]$arguments = "$arg1","$arg2","$arg3";
			$StudioInstallCmd = "$HDBInstallFile $arg1 $arg2 $arg3"
			Write-Host "   Installing HANA Studio..."
			Invoke-Expression $StudioInstallCmd

			$ws = New-Object -com WScript.Shell
			$Dt = $ws.SpecialFolders.Item("Desktop")
			$Scp = Join-Path -Path $Dt -ChildPath "SAP HANA Studio.lnk"
			$Sc = $ws.CreateShortcut($Scp)
			$Sc.TargetPath = "C:\Program Files\sap\hdbstudio\hdbstudio.exe"
			$Sc.Description = "hdbstudio"
			$Sc.Save()


		}
	}
}




Function DeployHANA  {

	[CmdletBinding(PositionalBinding=$false)]

	Param(		  		  
		  [String] $os = $default_os,
		  [String] $InstanceType = $default_InstanceType,
		  [String] $hostcount = $default_hostcount,
		  [String] $PlacementGroupName
		  )

	PrintIntro

	Write-Host "   Initialize-AWSDefaults -Region $Region"
	Initialize-AWSDefaults -Region $Region | Out-Null
	Write-Host ""
	Write-Host ""

	$MyAvailabilityZone = $AvailabilityZone
	$MyRegion = $Region
	$SnapshotId = GetSAPMediaSnapshot -volume $SoftwareDepotVol -region $Region
	Write-Host ""
        
    #Prompt for Number of HANA Nodes
    do {
           try {
             $valid = $true
             $hostcount = Read-Host "   Enter number of HANA Nodes (1-5) [$default_hostcount]"
               If([string]::IsNullOrEmpty($hostcount)) {
                     $hostcount = $default_hostcount
                  }
               } 
           catch {
			  $valid = $false
		   }
	  }
      until (([int]$hostcount -ge 1 -and [int]$hostcount -le 5) -and $valid)

	 
	$myInstanceArray = @("","c3.8xlarge","r3.2xlarge","r3.4xlarge","r3.8xlarge");
	$myInstanceDesc = @("","32 vCPU/60 GiB","8  vCPU/61 GiB","16 vCPU/122 GiB","32 vCPU/244 GiB (SAP Supported)")

	#Prompt for HANA instance types
    do {
           try {
             $valid = $true
			 Write-Host "   Supported Instance Types are below:"
			 Write-Host '   '   1: $myInstanceArray[1] $myInstanceDesc[1]
			 Write-Host '   '   2: $myInstanceArray[2] $myInstanceDesc[2]
			 Write-Host  '   '  3: $myInstanceArray[3] $myInstanceDesc[3]
			 Write-Host  '   '  4: $myInstanceArray[4] $myInstanceDesc[4]
			 
             $myInstanceIndex = Read-Host "   Enter instance type [1-4]"
               If([string]::IsNullOrEmpty($myInstanceIndex)) {
                     $myInstanceIndex = 4
                  }
               } 
           catch {
			  $valid = $false
		   }
	  }
      until (([int]$myInstanceIndex -ge 1 -and [int]$myInstanceIndex -le 4) -and $valid)
	
	$InstanceType = $myInstanceArray[$myInstanceIndex]
   
	Write-Host "   HANA Nodes: $hostcount, HANA Instance Type: $InstanceType"
    Write-Host ""
        

	$HANAMasterPass = ReadHANAPassword
	$GenericTemplateFile = $GenericTemplateFile_MN

    if($GenericTemplateFile){
        if(Test-Path $GenericTemplateFile){
		Write-Host ""
		Write-Host "   CloudFormation template file found in $GenericTemplateFile"
    	Write-Host ""
	   }
    } else {
        Write-Host "File $GenericTemplateFile not found!"
		$GenericTemplateFile=read-host "Enter the full path to cloudformation template file"
    }

	$timestamp = (get-date).toString(‘yyyyMMddhhmm’)

	if (!$PlacementGroupName) {
		$PlacementGroupName =  "AWS-HANA-PlacementGroup"
		Try {
			New-EC2PlacementGroup -GroupName $PlacementGroupName -Strategy cluster
			Write-Host "   Creating Placement Group $PlacementGroupName"
		}
		Catch {
			Write-Host "   Couldn't create new Placement Group $PlacementGroupName. Exists already ?"
            Write-Host ""
		}
	} else {
		Write-Host "   Using Placement Group $PlacementGroupName"
	}
        

                
	$ami =  GetLatestSUSEamiFromTable -region $Region
	if ($false) {
		$newami = Read-Host "    Found latest AMI $ami. [Enter] or Input a different AMI:"
		If([string]::IsNullOrEmpty($newami)) {
			$newami = $ami
		}
		$ami = $newami 
	}


	$ParametersArray = @()
    $ParametersArray += GetAmazonCFParameter "MyRegionAMI" $ami	
	$ParametersArray += GetAmazonCFParameter "DMZCIDR" $DMZCIDR
	$ParametersArray += GetAmazonCFParameter "PrivSubCIDR" $PrivSubCIDR
	$ParametersArray += GetAmazonCFParameter "VPCID" $VPC
	$ParametersArray += GetAmazonCFParameter "HANASubnet" $HANASubnet
	$ParametersArray += GetAmazonCFParameter "SnapShotID" $SnapshotId
	$ParametersArray += GetAmazonCFParameter "HANAMasterPass" $HANAMasterPass
	$ParametersArray += GetAmazonCFParameter "KeyName" $KeyName
	$ParametersArray += GetAmazonCFParameter "MyInstanceType" $InstanceType
	$ParametersArray += GetAmazonCFParameter "PlacementGroupName" $PlacementGroupName
	$ParametersArray += GetAmazonCFParameter "MyAvailabilityZone" $MyAvailabilityZone
	$ParametersArray += GetAmazonCFParameter "HostCount" $hostcount

	$StackName = "AWS-HANA-Deployment-" + $timestamp

	if ($IfDebug)  {
			$stack = New-CFNStack -StackName $StackName -Region $MyRegion -TemplateURL ${TemplateURL} -Parameters $ParametersArray  -OnFailure "ROLLBACK" -Verbose:$true -Debug 
                        Write-Host "   SAP HANA deployment in AWS initiated! Check AWS at console.aws.amazon.com for deployment progress!"
			Write-Host ""
			Write-Host ""
	} else {
		Try {
			$stack = New-CFNStack -StackName $StackName -TemplateURL  ${TemplateURL} -Parameters $ParametersArray  -OnFailure "ROLLBACK" -Verbose:$true -Debug 
			Write-Host "   SAP HANA deployment in AWS initiated! Check AWS at console.aws.amazon.com for deployment progress!"
			Write-Host ""
			Write-Host ""
		}
		Catch {
			Write-Host "   SAP HANA deployment Failed!"
			Write-Host ""
			Write-Host ""
		}
	}

	# Install HANA Studio
	Invoke-Expression InstallHANAStudio


}

$DeployHANACommand = "DeployHANA $args"
Invoke-Expression $DeployHANACommand
