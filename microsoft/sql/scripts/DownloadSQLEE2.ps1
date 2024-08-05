param(
	$DestShare,
	$DestServer,
    $SQLServerVersion
)        

if($SQLServerVersion -eq "2014") {
    Start-BitsTransfer -Source "http://download.microsoft.com/download/6/1/9/619E068C-7115-490A-BFE3-09BFDEF83CB9/SQLServer2014-x64-ENU.iso" -Destination "\\$DestServer\$DestShare\"
} 
else {
    Start-BitsTransfer -Source "http://download.microsoft.com/download/3/B/D/3BD9DD65-D3E3-43C3-BB50-0ED850A82AD5/SQLServer2012SP1-FullSlipstream-ENU-x64.iso" -Destination  "\\$DestServer\$DestShare\"
}
