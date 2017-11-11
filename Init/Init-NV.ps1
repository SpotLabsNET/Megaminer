
function GetPoolLocation()
{
  if("$Env:AZ_BATCH_ACCOUNT_NAME".Contains('au'))  
  {
    return 'asia' 
  }
  elseif("$Env:AZ_BATCH_ACCOUNT_NAME".Contains('ca')) 
  {
    return 'us' 
  }
  elseif("$Env:AZ_BATCH_ACCOUNT_NAME".Contains('in'))  
  {
    return 'europe' 
  }
  elseif("$Env:AZ_BATCH_ACCOUNT_NAME".Contains('kr'))  
  {
    return 'asia'
  }
  elseif("$Env:AZ_BATCH_ACCOUNT_NAME".Contains('br')) 
  {
    return 'us'  
  }
  elseif("$Env:AZ_BATCH_ACCOUNT_NAME".Contains('eu')) 
  {
    return 'europe' 
  }
  elseif("$Env:AZ_BATCH_ACCOUNT_NAME".Contains('jp'))  
  {
    return 'asia' 
  }
  elseif("$Env:AZ_BATCH_ACCOUNT_NAME".Contains('ap'))   
  {
    return 'europe' 
  }
  elseif("$Env:AZ_BATCH_ACCOUNT_NAME".Contains('uk'))     
  {
    return 'europe' 
  }
  elseif("$Env:AZ_BATCH_ACCOUNT_NAME".Contains('us'))     
  {
    return 'us' 
  }
  else                                 
  {
    return 'europe' 
  }
}

# Local Variables
$SourcesUrl = 'https://github.com/nicehash/excavator/releases/download/v1.2.11a/excavator_v1.2.11a_Win64.zip'
$ProviderText = 'ChocolateyGet'
$AllUsersText = 'AllUsers'
$RequiredText = 'Required'
$RebootServer = $false

# Batch Variables
$AzureBatchTaskId  = "$Env:AZ_BATCH_TASK_ID"
$AzureBatchPoolId  = "$Env:AZ_BATCH_POOL_ID"
$AzureBatchNodeId  = "$Env:AZ_BATCH_NODE_ID"
$AzureBatchAccount = "$Env:AZ_BATCH_ACCOUNT_NAME"

# Dump it all 
Write-Output -InputObject "`n$($Env)`n"

# Start.bat replacement
$StartContent = @"
setx GPU_FORCE_64BIT_PTR 1
setx GPU_MAX_HEAP_SIZE 100
setx GPU_USE_SYNC_OBJECTS 1
setx GPU_MAX_ALLOC_PERCENT 100
setx GPU_SINGLE_ALLOC_PERCENT 100

powershell -version 5.0 -noexit -executionpolicy bypass -windowstyle maximized -command "&.\multipoolminer.ps1 -wallet 1Ayf75rQAkGi3Gg3k326UGggzNx2hYwJ4f -username pauldmurphy -workername $env:AZ_BATCH_POOL_ID -interval 180 -location $(GetPoolLocation) -ssl -type nvidia,cpu -algorithm bitcore,blake,blake2s,blakecoin,blakevanilla,cryptonight,daggerhashimoto,darkcoinmod,decred,equihash,ethash,groestl,groestlcoin,hmq1725,keccak,lbry,lyra2re2,lyra2rev2,lyra2v2,lyra2z,maxcoin,myrgr,myriadcoing,myriadgroestl,neoscrypt,nist5,pascal,qubit,qubitcoin,scrypt,sha256,sia,sib,skein,skeincoin,timetravel,vanilla,x11,x11evo,x17,yescrypt,zuikkis -poolname miningpoolhubcoins,miningpoolhub,Zpool -currency btc,usd -donate 10"
"@

function Where-PnpDeviceHasNoProblems
{
  param
  (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage='Data to filter')]
    [Object]$InputObject
  )
  process
  {
    if ($InputObject.Problem -eq 'CM_PROB_NONE')
    {
      $InputObject
    }
  }
}

$HascismRoot = "$Env:ProgramData\hascism"
$RequireRoot =  (Join-Path  -Path $HascismRoot -ChildPath $RequiredText)

# Set the location
if(Test-Path -Path $HascismRoot)    { Remove-Item -Path $HascismRoot -Force -Recurse }
if(-not(Test-Path -Path $HascismRoot)) { New-Item -ItemType Directory -Path $HascismRoot }
if(-not(Test-Path -Path $RequireRoot)) { New-Item -ItemType Directory -Path $RequireRoot }
Set-Location -Path $HascismRoot

# Download Links
$M60Driver = 'https://go.microsoft.com/fwlink/?linkid=836843'
$M60Path   = (Join-Path  -Path $HascismRoot -ChildPath $RequiredText)
$M60File   = '385.41_grid_win10_server2016_64bit_international.exe'
$M60Full   = (Join-Path  -Path $M60Path -ChildPath $M60File)
if(-not(Test-Path -Path $M60Full)) {Invoke-WebRequest -UseBasicParsing -Uri ('{0}' -f $M60Driver) -OutFile $M60Full -Verbose}

# Ensure the M60 exists
$M60Device = (Get-PnpDevice -Class 'Display' -FriendlyName 'NVIDIA Tesla M60' -PresentOnly -ErrorAction SilentlyContinue)
if($null -eq $M60Device)
{
  # Ensure the M60 package
  if(-not(Test-Path -Path $M60Full))
  {
    Invoke-WebRequest -UseBasicParsing -Uri ('{0}' -f $M60Driver) -OutFile $M60Full  
  }

  # Install the M60 driver
  (& $M60Full /s)

  # Wait for M60 readystate
  $PnpDevice = (Get-PnpDevice -Class 'Display' -FriendlyName 'NVIDIA Tesla M60' -PresentOnly | Where-PnpDeviceHasNoProblems)
  while($PnpDevice -eq $null)           
  {
      Start-Sleep -Seconds 15
      $PnpDevice = (Get-PnpDevice -Class 'Display' -FriendlyName 'NVIDIA Tesla M60' -PresentOnly | Where-PnpDeviceHasNoProblems)
      $PnpDevice
  }
}

# VCx64
$VCx64Driver = 'https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe'
$VCx64Path   = (Join-Path  -Path $HascismRoot -ChildPath $RequiredText)
$VCx64File   = (Split-Path -Path $VCx64Driver -Leaf)
$VCx64Full   = (Join-Path  -Path $VCx64Path -ChildPath $VCx64File)
if(-not(Test-Path -Path $VCx64Full)) {Invoke-WebRequest -UseBasicParsing -Uri ('{0}' -f $VCx64Driver) -OutFile $VCx64Full -Verbose}

# VCx86
$VCx86Driver = 'https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x86.exe'
$VCx86Path   = (Join-Path  -Path $HascismRoot -ChildPath $RequiredText)
$VCx86File   = (Split-Path -Path $VCx86Driver -Leaf)
$VCx86Full   = (Join-Path  -Path $VCx86Path -ChildPath $VCx86File)
if(-not(Test-Path -Path $VCx86Full)) {Invoke-WebRequest -UseBasicParsing -Uri ('{0}' -f $VCx86Driver) -OutFile $VCx86Full -Verbose}

# VC64
$VC64Driver = 'https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe'
$VC64Path   = (Join-Path  -Path $HascismRoot -ChildPath $RequiredText)
$VC64File   = (Split-Path -Path $VC64Driver -Leaf)
$VC64Full   = (Join-Path  -Path $VC64Path -ChildPath $VC64File)
if(-not(Test-Path -Path $VC64Full)) {Invoke-WebRequest -UseBasicParsing -Uri ('{0}' -f $VC64Driver) -OutFile $VC64Full -Verbose}

# VC86
$VC86Driver = 'https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe'
$VC86Path   = (Join-Path  -Path $HascismRoot -ChildPath $RequiredText)
$VC86File   = (Split-Path -Path $VC86Driver -Leaf)
$VC86Full   = (Join-Path  -Path $VC86Path -ChildPath $VC86File)
if(-not(Test-Path -Path $VC86Full)) {Invoke-WebRequest -UseBasicParsing -Uri ('{0}' -f $VC86Driver) -OutFile $VC86Full -Verbose}

# Install package provider
Install-PackageProvider -ForceBootstrap -Force -Scope $AllUsersText -Name $ProviderText

# Setup Power Management
(& powercfg -s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c)

# Install Source Control
Install-Package -Force -ProviderName $ProviderText -Name Git,Git-Lfs -Verbose

# Install NetFx 3.5
Install-WindowsFeature -Name 'NET-Framework-Core' -IncludeManagementTools -Confirm:$false -ErrorAction Continue -Verbose

# Remove Windows Defender
#Remove-WindowsFeature -Name 'Windows-Defender-Features' -Restart:$false -IncludeManagementTools -Confirm:$false -ErrorAction Continue

# Install the Redists
(& $VC64Full /s)
(& $VC86Full /s)
(& $VCx64Full /s)
(& $VCx86Full /s)

# Install Azure PoSh
Install-Module -Force -Scope $AllUsersText -Name AzureRM -Verbose

# Install Azure Cli
Find-Package -IncludeDependencies -Name 'azure-cli' -Verbose | Install-Package -Force -ForceBootstrap -Verbose

# Install MultiPool
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
(& git clone --recursive https://github.com/SpotLabsNET/MultiPoolMiner.git)

# Install Excavator
cd MultiPoolMiner
Invoke-WebRequest -UseBasicParsing -Uri $SourcesUrl -OutFile (Split-Path -Leaf -Path $SourcesUrl)
Unblock-File   -Path .\excavator_v1.2.11a_Win64.zip
Expand-Archive -Path .\excavator_v1.2.11a_Win64.zip -DestinationPath .\Bin\Excavator

# Remove Windows Defender
Remove-WindowsFeature -Name 'Windows-Defender-Features' -Restart:$true -IncludeManagementTools -Confirm:$false -ErrorAction Continue

# Launch Miners
(& setx GPU_FORCE_64BIT_PTR 1)
(& setx GPU_MAX_HEAP_SIZE 100)
(& setx GPU_USE_SYNC_OBJECTS 1)
(& setx GPU_MAX_ALLOC_PERCENT 100)
(& setx GPU_SINGLE_ALLOC_PERCENT 100)

&.\MultiPoolMiner.ps1 -wallet 3BtgUnw3Rax59p8Fmk4VSgsH1BsYvJH1GP -username pauldmurphy -workername $env:AZ_BATCH_POOL_ID -interval 120 -Region $(GetPoolLocation) -ssl -type cpu,nvidia -algorithm cryptonight -poolname MiningPoolHub,NiceHash,MiningPoolHubCoins -currency btc,usd -donate 10
#.\MultiPoolMiner.ps1 -wallet 3BtgUnw3Rax59p8Fmk4VSgsH1BsYvJH1GP -username pauldmurphy -workername $env:AZ_BATCH_POOL_ID -interval 120 -Region $(GetPoolLocation) -ssl -type cpu,nvidia -algorithm Bitcore,Blakecoin,Blake2s,BlakeVanilla,C11,CryptoNight,Ethash,X11,Decred,Equihash,Groestl,HMQ1725,JHA,Keccak,Lbry,Lyra2RE2,Lyra2z,MyriadGroestl,NeoScrypt,Nist5,Pascal,Quark,Qubit,Scrypt,SHA256,Sia,Sib,Skunk,Skein,Timetravel,Tribus,BlakeVanilla,Veltor,X11,X11evo,X17,Yescrypt -poolname MiningPoolHub,NiceHash,MiningPoolHubCoins -currency btc,usd -donate 10