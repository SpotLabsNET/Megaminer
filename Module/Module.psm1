
function Invoke-Hashpower0
{ 
#--------------optional parameters...to allow direct launch without prompt to user
param(
    [Parameter(Mandatory = $false)]
    [String]$MiningMode = $null#= "AUTOMATIC/MANUAL"
    #[String]$MiningMode = "MANUAL"
    ,
    [Parameter(Mandatory = $false)]
    [string]$PoolsName =$null
    #[string]$PoolsName = "YIIMP"
    ,
    [Parameter(Mandatory = $false)]
    [string]$CoinsName =$null
    #[string]$CoinsName ="decred"
)

. .\Include.ps1

#check parameters

if (($MiningMode -eq "MANUAL") -and ($PoolsName.count -gt 1)) { write-host ONLY ONE POOL CAN BE SELECTED ON MANUAL MODE}


#--------------Load config.txt file

$Location=(Get-Content config.txt | Where-Object {$_ -like '@@LOCATION=*'} )-replace '@@LOCATION=',''
$CoinsWallets=@{} #needed for anonymous pools load
     (Get-Content config.txt | Where-Object {$_ -like '@@WALLET_*=*'}) -replace '@@WALLET_*=*','' | ForEach-Object {$CoinsWallets.add(($_ -split "=")[0],($_ -split "=")[1])}


$SelectedOption=""

#-----------------Ask user for mode to mining AUTO/MANUAL to use, if a pool is indicated in parameters no prompt

Clear-Host
write-host ..............................................................................................
write-host ...................SELECT MODE TO MINE.....................................................
write-host ..............................................................................................

$Modes=@()
$Modes += [pscustomobject]@{"Option"=0;"Mode"='AUTOMATIC';"Explanation"='Not necesary choose coin to mine, program choose more profitable coin based on pool´s current statistics'}
$Modes += [pscustomobject]@{"Option"=1;"Mode"='AUTOMATIC24h';"Explanation"='Same as Automatic mode but based on pools/WTM reported last 24h profit'}
$Modes += [pscustomobject]@{"Option"=2;"Mode"='MANUAL';"Explanation"='You select coin to mine'}

$Modes | Format-Table Option,Mode,Explanation  | out-host


If ($MiningMode -eq "")  
    {
     $SelectedOption = Read-Host -Prompt 'SELECT ONE OPTION:'
     $MiningMode=$Modes[$SelectedOption].Mode
     write-host SELECTED OPTION::$MiningMode
    }
    else 
    {write-host SELECTED BY PARAMETER OPTION::$MiningMode}


    

#-----------------Ask user for pool/s to use, if a pool is indicated in parameters no prompt

    switch ($MiningMode) {
            "Automatic" {$Pools=Get-Pools -Querymode "Info" | Where-Object ActiveOnAutomaticMode -eq $true | sort name }
            "Automatic24h" {$Pools=Get-Pools -Querymode "Info" | Where-Object ActiveOnAutomatic24hMode -eq $true | sort name }
            "Manual" {$Pools=Get-Pools -Querymode "Info" | Where-Object ActiveOnManualMode -eq $true | sort name }
            }

$Pools | Add-Member Option "0"
$counter=0
$Pools | ForEach-Object {
        $_.Option=$counter
        $counter++}


if ($MiningMode -ne "Manual"){
        $Pools += [pscustomobject]@{"Disclaimer"="";"ActiveOnManualMode"=$false;"ActiveOnAutomaticMode"=$true;"ActiveOnAutomatic24hMode"=$true;"name"='ALL POOLS';"option"=99}}


#Clear-Host
write-host ..............................................................................................
write-host ...................SELECT POOL/S  TO MINE.....................................................
write-host ..............................................................................................

$Pools | Format-Table Option,name,disclaimer | out-host



If (($PoolsName -eq "") -or ($PoolsName -eq $null))
    {


    if ($MiningMode -eq "manual"){
           $SelectedOption = Read-Host -Prompt 'SELECT ONE OPTION:'
           while ($SelectedOption -like '*,*') {
                    $SelectedOption = Read-Host -Prompt 'SELECT ONLY ONE OPTION:'
                    }
           }
    if ($MiningMode -ne "Manual"){
            $SelectedOption = Read-Host -Prompt 'SELECT OPTION/S (separated by comma):'
            if ($SelectedOption -eq "99") {
                  $SelectedOption=""
                  $Pools | Where-Object Option -ne 99 | ForEach-Object {
                        if  ($SelectedOption -eq "") {$comma=''} else {$comma=','}
                        $SelectedOption += $comma+$_.Option
                        }
                         } 
            
            }
    $SelectedOptions = $SelectedOption -split ','        
    $PoolsName=""            
    $SelectedOptions |ForEach-Object {
            if  ($PoolsName -eq "") {$comma=''} else {$comma=','}
            $PoolsName+=$comma+$Pools[$_].name
            } 
    
    $PoolsName=('#'+$PoolsName) -replace '# ,','' -replace ' ','' -replace '#','' #In test mode this is not necesary, in real execution yes...??????

     write-host SELECTED OPTION:: $PoolsName
    }
    else 
        {
            write-host SELECTED BY PARAMETER ::$PoolsName
        }



#-----------------Ask user for coins----------------------------------------------------


if ($MiningMode -eq "manual"){

            If ($CoinsName -eq "")  
                {

                    #Load coins for pool´s file
                    if ($SelectedPool.ApiData -eq $false)  
                        {write-host        POOL API NOT EXISTS, SOME DATA NOT AVAILABLE!!!!!}
                    else 
                        {write-host CALLING POOL API........}



                    $CoinsPool=Get-Pools -Querymode "Menu" -PoolsFilterList $PoolsName -location $Location |Select-Object info,symbol,algorithm,Workers,PoolHashRate,Blocks_24h -unique | Sort-Object info

                    $CoinsPool | Add-Member Option "0"
                    $CoinsPool | Add-Member YourHashRate ([Double]0.0)
                    $CoinsPool | Add-Member BTCPrice ([Double]0.0)
                    $CoinsPool | Add-Member BTCChange24h ([Double]0.0)
                    $CoinsPool | Add-Member DiffChange24h ([Double]0.0)
                    $CoinsPool | Add-Member Reward ([Double]0.0)
                    $CoinsPool | Add-Member BtcProfit ([Double]0.0)
                    $CoinsPool | Add-Member LocalProfit ([Double]0.0)
                    $CoinsPool | Add-Member LocalPrice ([Double]0.0)
                    
                    
                    
                    $ManualMiningApiUse=(Get-Content config.txt | Where-Object {$_ -like '@@MANUALMININGAPIUSE=*'} )-replace '@@MANUALMININGAPIUSE=',''    
                
                
                    

                    if ($ManualMiningApiUse -eq $true){
                                        try {
                                                write-host CALLING WHATTOMINE API.........    
                                                $WTMResponse = Invoke-WebRequest "https://whattomine.com/coins.json" -UseBasicParsing -TimeoutSec 3 | ConvertFrom-Json | Select-Object -ExpandProperty coins
                                                write-host CALLING BITTREX API............
                                                $BTXResponse = (Invoke-WebRequest "https://bittrex.com/api/v1.1/public/getmarketsummaries" -TimeoutSec 5| ConvertFrom-Json|Select-Object -ExpandProperty result)  
                                                write-host CALLING COINDESK API............
                                                $CDKResponse = Invoke-WebRequest "https://api.coindesk.com/v1/bpi/currentprice.json" -UseBasicParsing -TimeoutSec 3 | ConvertFrom-Json | Select-Object -ExpandProperty BPI
                                            } catch{}
                                } 

                                

                    $Counter = 0
                    $CoinsPool | ForEach-Object {

                                                $_.Option=$Counter                                                                
                                                $counter++
                                                $_.YourHashRate=(Get-Best-Hashrate-Algo $_.Algorithm).hashrate

                                                if ($ManualMiningApiUse -eq $true -and $_.symbol -ne "" -and $_.symbol -ne $null){

                                                                #Get data from bittrex global api call
                                                                if ($BTXResponse -ne $null) {
                                                                                            foreach ($BtxCoin in $BTXResponse)
                                                                                                     {if ($BtxCoin.marketname -eq ("btc-"+$_.symbol)) {  $_.BTCPrice=$BtxCoin.Last}}
                                                                                            }

                                                               
                                                                #If no data try with CRYPTOPIA                                    
                                                                if ($_.BTCPrice -eq 0){
                                                                                        $ApiResponse = $null
                                                                                        "CALLING CRYPTOPIA API........"+$_.symbol+"_BTC" | out-Host
                                                                                        try {
                                                                                                $Apicall="https://www.cryptopia.co.nz/api/GetMarket/"+$_.symbol+'_BTC'
                                                                                                $ApiResponse=(Invoke-WebRequest $ApiCall -UseBasicParsing  -TimeoutSec 2| ConvertFrom-Json|Select-Object -ExpandProperty data)
                                                                                            } catch{}
                                                                                        
                                                                                        if ($ApiResponse -ne $null) {
                                                                                                                    $_.BTCPrice=$ApiResponse.LastPrice
                                                                                                                    #$_.BTCChange24h=$ApiResponse.Change
                                                                                                                    }
                                                                                    }
                                                                
                                                                
                                                                #Data from WTM
                                                                    if ($WTMResponse -ne $null) {
                                                                                $WtmCoin=$WTMResponse.($_.Info)
                                                                                if ($WtmCoin -ne $null)
                                                                                    {
                                                                                   
                                                                                    if ($WtmCoin.difficulty24 -ne 0)  {$_.DiffChange24h=(1-($WtmCoin.difficulty/$WtmCoin.difficulty24))*100}
                                                                                    #WTM returns default data as 3x480 hashrates
                                                                                    $WTMFactor=$null
                                                                                    switch ($_.Algorithm)
                                                                                                {
                                                                                                        "Ethash"{$WTMFactor=84000000}
                                                                                                        "Groestl"{$WTMFactor=630900000 }
                                                                                                        "X11Gost"{$WTMFactor=20100000}
                                                                                                        "Cryptonight"{$WTMFactor=2190}
                                                                                                        "equihash"{$WTMFactor=870}
                                                                                                        "lyra2v2"{$WTMFactor=14700000}
                                                                                                        "Neoscrypt"{$WTMFactor=1950000}
                                                                                                        "Lbry"{$WTMFactor=315000000}
                                                                                                        "sia"{$WTMFactor=3450000000} #Blake2b
                                                                                                        "decred"{$WTMFactor=5910000000} #Blake14r
                                                                                                        "Pascal"{$WTMFactor=2100000000}
                                                                                                }

                                                                                    if ($WTMFactor -ne $null) {
                                                                                                    $_.Reward=[double]([double]$WtmCoin.estimated_rewards * ([double]$_.YourHashRate/[double]$WTMFactor))
                                                                                                    $_.BtcProfit=[double]([double]$WtmCoin.Btc_revenue * ([double]$_.YourHashRate/[double]$WTMFactor))
                                                                                                    }

                                                                                    }

                                                                                }
                                                                 

                                                                    if ($location -eq 'Europe') {$_.LocalProfit = [double]$CDKResponse.eur.rate * [double]$_.BtcProfit; $_.LocalPrice = [double]$CDKResponse.eur.rate * [double]$_.BtcPrice}
                                                                    if ($location -eq 'US' -or $location -eq 'ASIA')     {$_.LocalProfit = [double]$CDKResponse.usd.rate * [double]$_.BtcProfit; $_.LocalPrice = [double]$CDKResponse.usd.rate * [double]$_.BtcPrice}
                                                                    if ($location -eq 'GB')     {$_.LocalProfit = [double]$CDKResponse.gbp.rate * [double]$_.BtcProfit; $_.LocalPrice = [double]$CDKResponse.gbp.rate * [double]$_.BtcPrice}
                                            
                                                                    
                                                                                                                            
                                                                 

                                                                }
                                                                     
                                                                

                                              
                                             }
                    
                    Clear-Host
                    write-host ....................................................................................................
                    write-host ............................SELECT COIN TO MINE.....................................................
                    write-host ....................................................................................................

                    #Only one pool is allowed in manual mode at this point
                    $SelectedPool=$Pools | where name -eq $PoolsName
                    
                    if ($SelectedPool.ApiData -eq $false)  {write-host        ----POOL API NOT EXISTS, SOME DATA NOT AVAILABLE---}

                    switch ($location) {
                        'Europe' {$LabelPrice="EurPrice"; $LabelProfit="EurProfit" ; $localBTCvalue = [double]$CDKResponse.eur.rate}
                        'US'     {$LabelPrice="UsdPrice" ; $LabelProfit="UsdProfit" ; $localBTCvalue = [double]$CDKResponse.usd.rate}
                        'GB'     {$LabelPrice="GbpPrice" ; $LabelProfit="GbpProfit" ; $localBTCvalue = [double]$CDKResponse.gbp.rate}

                       }

                 

                    $CoinsPool  | Format-Table -Wrap (
                                @{Label = "Opt."; Expression = {$_.Option}; Align = 'right'} ,
                                @{Label = "Name"; Expression = {$_.info.toupper()}; Align = 'left'} ,
                                @{Label = "Symbol"; Expression = {$_.symbol}; Align = 'left'},   
                                @{Label = "Algorithm"; Expression = {$_.algorithm.tolower()}; Align = 'left'},
                                @{Label = "Workers"; Expression = {$_.Workers}; Align = 'right'},   
                                #@{Label = "PoolHash"; Expression = {"$($_.PoolHashRate | ConvertTo-Hash)/s"}; Align = 'right'},   
                                @{Label = "HashRate"; Expression = {(ConvertTo-Hash ($_.YourHashRate))+"/s"}; Align = 'right'},   
                                #@{Label = "Blocks_24h"; Expression = {$_.Blocks_24h}; Align = 'right'},
                                @{Label = "BTCPrice"; Expression = {[math]::Round($_.BTCPrice,6)}; Align = 'right'},
                                @{Label = $LabelPrice; Expression = { [math]::Round($_.LocalPrice,2)}; Align = 'right'},
                                #@{Label = "DiffChange24h"; Expression = {([math]::Round($_.DiffChange24h,1)).ToString()+'%'}; Align = 'right'},
                                @{Label = "Reward"; Expression = {([math]::Round($_.Reward,3))}; Align = 'right'},
                                @{Label = "BtcProfit"; Expression = {([math]::Round($_.BtcProfit,6))}; Align = 'right'},
                                @{Label = $LabelProfit; Expression = {[math]::Round($_.LocalProfit,2)}; Align = 'right'}
                                )  | out-host        
            

                    $SelectedOption = Read-Host -Prompt 'SELECT ONE OPTION:'
                    while ($SelectedOption -like '*,*') {
                                                        $SelectedOption = Read-Host -Prompt 'SELECT ONLY ONE OPTION:'
                                                        }
                    $CoinsName = $CoinsPool[$SelectedOption].Info -replace '_',',' #for dual mining
                    $AlgosName = $CoinsPool[$SelectedOption].Algorithm -replace '_',',' #for dual mining

                    write-host SELECTED OPTION:: $CoinsName - $AlgosName
                }
            else 
                {

                    write-host SELECTED BY PARAMETER :: $CoinsName
                }                    

           
            }

            
#-----------------Launch Command
            $command="./core.ps1 -MiningMode $MiningMode -PoolsName $PoolsName"
            if ($MiningMode -eq "manual"){$command+=" -Coinsname $CoinsName -Algorithm $AlgosName"} 

            #write-host $command
            Invoke-Expression $command

        }
function Invoke-Hashpower1
{  

param(
    [Parameter(Mandatory = $false)]
    [Array]$Algorithm = $null,

    [Parameter(Mandatory = $false)]
    [Array]$PoolsName = $null,

    [Parameter(Mandatory = $false)]
    [array]$CoinsName= $null,

    [Parameter(Mandatory = $false)]
    [String]$Proxy = "", #i.e http://192.0.0.1:8080 

    [Parameter(Mandatory = $false)]
    [String]$MiningMode = $null

)

. .\Include.ps1


##Parameters for testing, must be commented on real use

#$MiningMode='Automatic'
#$MiningMode='Automatic24h'
#$MiningMode='Manual'

#$PoolsName=('zpool','mining_pool_hub')
#$PoolsName='whattomine_virtual'
#$PoolsName='yiimp'
#$PoolsName=('hash_refinery','zpool','mining_pool_hub')
#$PoolsName='mining_pool_hub'
#$PoolsName='zpool'
#$PoolsName='BLOCKS_FACTORY'

#$PoolsName='Suprnova'
#$PoolsName="Nicehash"

#$Coinsname =('bitcore','Signatum','Zcash')
#$Coinsname ='bitcore'
#$Algorithm =('x11')


#--------------Load config.txt file


$location=@()
$Types=@()
$Currency=@()


$Location=(Get-Content config.txt | Where-Object {$_ -like '@@LOCATION=*'} )-replace '@@LOCATION=',''
$Donate=(Get-Content config.txt | Where-Object {$_ -like '@@DONATE=*'} )-replace '@@DONATE=',''
$UserName=(Get-Content config.txt | Where-Object {$_ -like '@@USERNAME=*'} )-replace '@@USERNAME=',''
$Types=(Get-Content config.txt | Where-Object {$_ -like '@@TYPE=*'}) -replace '@@TYPE=','' -split ','
$Interval=(Get-Content config.txt | Where-Object {$_ -like '@@INTERVAL=*'}) -replace '@@INTERVAL=',''
$WorkerName=(Get-Content config.txt | Where-Object {$_ -like '@@WORKERNAME=*'} )-replace '@@WORKERNAME=',''
$Currency=(Get-Content config.txt | Where-Object {$_ -like '@@CURRENCY=*'} )-replace '@@CURRENCY=',''
$GpuPlatform=(Get-Content config.txt | Where-Object {$_ -like '@@GPUPLATFORM=*'} )-replace '@@GPUPLATFORM=',''
$CoinsWallets=@{} 
     (Get-Content config.txt | Where-Object {$_ -like '@@WALLET_*=*'}) -replace '@@WALLET_*=*','' | ForEach-Object {$CoinsWallets.add(($_ -split "=")[0],($_ -split "=")[1])}



Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

Get-ChildItem . -Recurse | Unblock-File
try {if ((Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {Start-Process powershell -Verb runAs -ArgumentList "Add-MpPreference -ExclusionPath '$(Convert-Path .)'"}}catch {}

if ($Proxy -eq "") {$PSDefaultParameterValues.Remove("*:Proxy")}
else {$PSDefaultParameterValues["*:Proxy"] = $Proxy}


$ActiveMiners = @()

#Start the log
Clear-log
Start-Transcript ".\Logs\$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"


#Set donation parameters
$LastDonated = (Get-Date).AddDays(-1).AddHours(1)
$UserNameDonate = "tutulino"
$WorkerNameDonate = "Megaminer"
$CoinsWalletsDonate=@{}  
    (Get-Content config.txt | Where-Object {$_ -like '@@WALLETDONATE_*=*'}) -replace '@@WALLETDONATE_*=*','' | ForEach-Object {$CoinsWalletsDonate.add(($_ -split "=")[0],($_ -split "=")[1])}

$UserNameBackup = $UserName
$WorkerNameBackup = $WorkerName
$CoinsWalletsBackup=$CoinsWallets


$ActiveMinersIdCounter=0
$Activeminers=@()
$BechmarkintervalTime=(Get-Content config.txt | Where-Object {$_ -like '@@BENCHMARKTIME=*'} )-replace '@@BENCHMARKTIME=',''
$Screen=(Get-Content config.txt | Where-Object {$_ -like '@@STARTSCREEN=*'} )-replace '@@STARTSCREEN=',''
$ProfitsScreenLimit=40
$ShowBestMinersOnly=$true
$FirstTotalExecution =$true

Clear-Host
set-WindowSize 120 60 

<#
$GpuPlatform= $([array]::IndexOf((Get-WmiObject -class CIM_VideoController | Select-Object -ExpandProperty AdapterCompatibility), 'Advanced Micro Devices, Inc.')) 
 if ($GpuPlatform -eq -1) {$GpuPlatform= $([array]::IndexOf((Get-WmiObject -class CIM_VideoController | Select-Object -ExpandProperty AdapterCompatibility), 'NVIDIA')) } #For testing amd miners on nvidia
#>


    


#---Paraneters checking

if ($MiningMode -ne 'Automatic' -and $MiningMode -ne 'Manual' -and $MiningMode -ne 'Automatic24h'){
    "Parameter MiningMode not valid, valid options: Manual, Automatic, Automatic24h" |Out-host
    EXIT
   }


   
$PoolsChecking=Get-Pools -Querymode "info" -PoolsFilterList $PoolsName -CoinFilterList $CoinsName -Location $location -AlgoFilterList $Algorithm   

$PoolsErrors=@()
switch ($MiningMode){
    "Automatic"{$PoolsErrors =$PoolsChecking |Where-Object ActiveOnAutomaticMode -eq $false}
    "Automatic24h"{$PoolsErrors =$PoolsChecking |Where-Object ActiveOnAutomatic24hMode -eq $false}
    "Manual"{$PoolsErrors =$PoolsChecking |Where-Object ActiveOnManualMode -eq $false }
    }


$PoolsErrors |ForEach-Object {
    "Selected MiningMode is not valid for pool "+$_.name |Out-host
    EXIT
}



if ($MiningMode -eq 'Manual' -and ($Coinsname | Measure-Object).count -gt 1){
    "On manual mode only one coin must be selected" |Out-host
    EXIT
   }


if ($MiningMode -eq 'Manual' -and ($Coinsname | Measure-Object).count -eq 0){
    "On manual mode must select one coin" |Out-host
    EXIT
   }   
 
if ($MiningMode -eq 'Manual' -and ($Algorithm | measure-object).count -gt 1){
    "On manual mode only one algorithm must be selected" |Out-host
    EXIT
   }
    





#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#This loop will be runnig forever
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------

while ($true) {
    
    $NextInterval=[int]$Interval

    #Activate or deactivate donation
    if ((Get-Date).AddDays(-1).AddMinutes($Donate) -ge $LastDonated) {
        $UserName = $UserNameDonate
        $WorkerName = $WorkerNameDonate
        $CoinsWallets= $CoinsWalletsDonate
        }
    if ((Get-Date).AddDays(-1) -ge $LastDonated) {
        $UserName = $UserNameBackup
        $WorkerName = $WorkerNameBackup
        $LastDonated = Get-Date
        $CoinsWallets = $CoinsWalletsBackup
       }
        

    $Rates = [PSCustomObject]@{}
    $Currency | ForEach-Object {$Rates | Add-Member $_ (Invoke-WebRequest "https://api.cryptonator.com/api/ticker/btc-$_" -UseBasicParsing | ConvertFrom-Json).ticker.price}

 

    #Load information about the Pools, only must read parameter passed files (not all as mph do), level is Pool-Algo-Coin
     do
        {
        $Pools=Get-Pools -Querymode "core" -PoolsFilterList $PoolsName -CoinFilterList $CoinsName -Location $location -AlgoFilterList $Algorithm
        if  ($Pools.Count -eq 0) {"NO POOLS!....retry in 10 sec" | Out-Host;Start-Sleep 10}
        }
    while ($Pools.Count -eq 0) 
    
    


    #Load information about the Miner asociated to each Coin-Algo-Miner

    $Miners= @()
    

    foreach ($MinerFile in (Get-ChildItem "Miners" | Where-Object extension -eq '.json'))  
        {
            try { $Miner =$MinerFile | Get-Content | ConvertFrom-Json } 
            catch 
                {   "-------BAD FORMED JSON: $MinerFile" | Out-host 
                Exit}
 
            #Only want algos selected types
            If ($Types.Count -ne 0 -and (Compare-Object $Types $Miner.types -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0)
                {

                    foreach ($Algo in ($Miner.Algorithms))
                        {
                            $HashrateValue= 0
                            $HashrateValueDual=0
                            $Hrs=$null

                            ##Algoname contains real name for dual and no dual miners
                            $AlgoName =  ($Algo.PSObject.Properties.Name -split ("_"))[0]
                            $AlgoNameDual = ($Algo.PSObject.Properties.Name -split ("_"))[1]

                            $Hrs = Get-Hashrates -minername $Minerfile.basename -algorithm $Algo.PSObject.Properties.Name

                            $HashrateValue=[long]($Hrs -split ("_"))[0]
                            $HashrateValueDual=[long]($Hrs -split ("_"))[1]

                            

                            #Only want algos pools has  

                                $Pools | where-object Algorithm -eq $AlgoName | ForEach-Object {
                                    
                                        if ((($Pools | Where-Object Algorithm -eq $AlgoNameDual) -ne  $null) -or ($Miner.Dualmining -eq $false)){

                                           if ($_.info -eq $Miner.DualMiningMainCoin -or $Miner.Dualmining -eq $false) {  #not allow dualmining if main coin not coincide
                                           
                                             $Arguments = $Miner.Arguments  -replace '#PORT#',$_.Port -replace '#SERVER#',$_.Host -replace '#PROTOCOL#',$_.Protocol -replace '#LOGIN#',$_.user -replace '#PASSWORD#',$_.Pass -replace "#GpuPlatform#",$GpuPlatform  -replace '#ALGORITHM#',$Algoname -replace '#ALGORITHMPARAMETERS#',$Algo.PSObject.Properties.Value -replace '#WORKERNAME#',$WorkerName
                                             if ($Miner.PatternConfigFile -ne $null) {
                                                             $ConfigFileArguments = (get-content $Miner.PatternConfigFile -raw)  -replace '#PORT#',$_.Port -replace '#SERVER#',$_.Host -replace '#PROTOCOL#',$_.Protocol -replace '#LOGIN#',$_.user -replace '#PASSWORD#',$_.Pass -replace "#GpuPlatform#",$GpuPlatform   -replace '#ALGORITHM#',$Algoname -replace '#ALGORITHMPARAMETERS#',$Algo.PSObject.Properties.Value -replace '#WORKERNAME#',$WorkerName
                                                        }

                                                if ($MiningMode -eq 'Automatic24h') {
                                                        $MinerProfit=[Double]([double]$HashrateValue * [double]$_.Price24h)}
                                                    else {
                                                        $MinerProfit=[Double]([double]$HashrateValue * [double]$_.Price)}

                                                $PoolAbbName=$_.Abbname
                                                $PoolName = $_.name
                                                $PoolWorkers = $_.Poolworkers
                                                $MinerProfitDual = $null
                                                $PoolDual = $null
                                                

                                                if ($Miner.Dualmining) 
                                                    {
                                                    if ($MiningMode -eq 'Automatic24h')   {
                                                        $PoolDual = $Pools |where-object Algorithm -eq $AlgoNameDual | sort-object price24h -Descending| Select-Object -First 1
                                                        $MinerProfitDual = [Double]([double]$HashrateValueDual * [double]$PoolDual.Price24h)
                                                         }   

                                                         else {
                                                                $PoolDual = $Pools |where-object Algorithm -eq $AlgoNameDual | sort-object price24h -Descending| Select-Object -First 1
                                                                $MinerProfitDual = [Double]([double]$HashrateValueDual * [double]$PoolDual.Price)
                                                                }

                                                    $Arguments = $Arguments -replace '#PORTDUAL#',$PoolDual.Port -replace '#SERVERDUAL#',$PoolDual.Host  -replace '#PROTOCOLDUAL#',$PoolDual.Protocol -replace '#LOGINDUAL#',$PoolDual.user -replace '#PASSWORDDUAL#',$PoolDual.Pass  -replace '#ALGORITHMDUAL#',$AlgonameDual  
                                                    if ($Miner.PatternConfigFile -ne $null) {
                                                                        $ConfigFileArguments = (get-content $Miner.PatternConfigFile -raw) -replace '#PORTDUAL#',$PoolDual.Port -replace '#SERVERDUAL#',$PoolDual.Host  -replace '#PROTOCOLDUAL#',$PoolDual.Protocol -replace '#LOGINDUAL#',$PoolDual.user -replace '#PASSWORDDUAL#',$PoolDual.Pass -replace '#ALGORITHMDUAL#',$AlgonameDual
                                                                        }

                                                    $PoolAbbName += '|' + $PoolDual.Abbname
                                                    $PoolName += '|' + $PoolDual.name
                                                    if ($PoolDual.workers -ne $null) {$PoolWorkers += '|' + $PoolDual.workers}

                                                    $AlgoNameDual=$AlgoNameDual.toupper()
                                                    $PoolDual.Info=$PoolDual.Info.tolower()
                                                    }
                                                
                                                
                                                $Miners += [pscustomobject] @{  
                                                                    Algorithm = $AlgoName.toupper()
                                                                    AlgorithmDual = $AlgoNameDual
                                                                    Algorithms=$Algo.PSObject.Properties.Name
                                                                    Coin = $_.Info.tolower()
                                                                    CoinDual = $PoolDual.Info
                                                                    Name = $Minerfile.basename
                                                                    Types = $Miner.Types
                                                                    Path = $Miner.Path
                                                                    HashRate = $HashRateValue
                                                                    HashRateDual = $HashrateValueDual
                                                                    API = $Miner.API
                                                                    Port =$Miner.APIPort
                                                                    Wrap =$Miner.Wrap
                                                                    URI = $Miner.URI
                                                                    Arguments=$Arguments
                                                                    Profit=$MinerProfit
                                                                    ProfitDual=$MinerProfitDual
                                                                    PoolPrice=$_.Price
                                                                    PoolPriceDual=$PoolDual.Price
                                                                    PoolName = $PoolName
                                                                    PoolAbbName = $PoolAbbName
                                                                    PoolWorkers = $PoolWorkers
                                                                    DualMining = $Miner.Dualmining
                                                                    Username = $_.user
                                                                    WalletMode=$_.WalletMode
                                                                    Host =$_.Host
                                                                    ExtractionPath = $Miner.ExtractionPath
                                                                    GenerateConfigFile = $miner.GenerateConfigFile
                                                                    ConfigFileArguments = $ConfigFileArguments
                                                                    Location = $_.location
                                                                    PrelaunchCommand = $Miner.PrelaunchCommand

                                                                }
                            
                                            }                       
                                         }          
     
                            }            
                        }
                }            
        }
             

        

    #Launch download of miners    
    $Miners |
        where-object URI -ne $null | 
        where-object ExtractionPath -ne $null | 
        where-object Path -ne $null | 
        where-object URI -ne "" | 
        where-object ExtractionPath -ne "" | 
        where-object Path -ne "" | 
        Select-Object URI, ExtractionPath,Path -Unique | ForEach-Object {Start-Downloader -URI $_.URI  -ExtractionPath $_.ExtractionPath -Path $_.Path}
    

    
    #Paint no miners message
    $Miners = $Miners | Where-Object {Test-Path $_.Path}
    if ($Miners.Count -eq 0) {"NO MINERS!" | Out-Host ; EXIT}


    #Update the active miners list which is alive for  all execution time
    $ActiveMiners | ForEach-Object {
                    #Search miner to update data
                
                     $Miner = $miners | Where-Object Name -eq $_.Name | 
                            Where-Object Coin -eq $_.Coin | 
                            Where-Object Algorithm -eq $_.Algorithm | 
                            Where-Object CoinDual -eq $_.CoinDual | 
                            Where-Object AlgorithmDual -eq $_.AlgorithmDual | 
                            Where-Object PoolAbbName -eq $_.PoolAbbName |
                            Where-Object Arguments -eq $_.Arguments |
                            Where-Object Location -eq $_.Location |
                            Where-Object ConfigFileArguments -eq $_.ConfigFileArguments

                    $_.Best = $false
                    $_.NeedBenchmark = $false
                    $_.ConsecutiveZeroSpeed=0
                    #Mark as cancelled if more than 3 fails and running less than 180 secs, if no other alternative option, try forerever

                    $TimeActive=($_.ActiveTime.Hours*3600)+($_.ActiveTime.Minutes*60)+$_.ActiveTime.Seconds
                    if (($_.FailedTimes -gt 3) -and ($TimeActive -lt 180) -and (($ActiveMiners | Measure-Object).count -gt 1)){
                            $_.IsValid=$False 
                            $_.Status='Cancelled'
                        }
                   
                    if (($Miner | Measure-Object).count -gt 1) {Out-host DUPLICATED ALGO $MINER.ALGORITHM ON $MINER.NAME;EXIT}                 

                    if ($Miner) {
                        $_.Types  = $Miner.Types
                        $_.Profit  = $Miner.Profit
                        $_.ProfitDual  = $Miner.ProfitDual
                        $_.Profits = if ($Miner.AlgorithmDual -ne $null) {$Miner.ProfitDual+$Miner.Profit} else {$Miner.Profit}
                        $_.PoolPrice = $Miner.PoolPrice
                        $_.PoolPriceDual = $Miner.PoolPriceDual
                        $_.HashRate  = [double]$Miner.HashRate
                        $_.HashRateDual  = [double]$Miner.HashRateDual
                        $_.Hashrates   = if ($Miner.AlgorithmDual -ne $null) {(ConvertTo-Hash ($Miner.HashRate)) + "/s|"+(ConvertTo-Hash $Miner.HashRateDual) + "/s"} else {(ConvertTo-Hash $Miner.HashRate) +"/s"}
                        $_.PoolWorkers = $Miner.PoolWorkers
                        if ($_.Status -ne 'Cancelled') {$_.IsValid=$true} 
                    
                            }
                    else {
                            $_.IsValid=$false #simulates a delete
                            }
                
                }


    ##Add new miners to list
    $Miners | ForEach-Object {
                
                    $ActiveMiner = $ActiveMiners | Where-Object Name -eq $_.Name | 
                            Where-Object Coin -eq $_.Coin | 
                            Where-Object Algorithm -eq $_.Algorithm | 
                            Where-Object CoinDual -eq $_.CoinDual | 
                            Where-Object AlgorithmDual -eq $_.AlgorithmDual | 
                            Where-Object PoolAbbName -eq $_.PoolAbbName |
                            Where-Object Arguments -eq $_.Arguments|
                            Where-Object Arguments -eq $_.Arguments |
                            Where-Object Location -eq $_.Location |
                            Where-Object ConfigFileArguments -eq $_.ConfigFileArguments

                
                    if ($ActiveMiner -eq $null) {
                        $ActiveMiners += [PSCustomObject]@{
                            Id                   = $ActiveMinersIdCounter
                            Algorithm            = $_.Algorithm
                            AlgorithmDual        = $_.AlgorithmDual
                            Algorithms           = $_.Algorithms
                            Name                 = $_.Name
                            Coin                 = $_.coin
                            CoinDual             = $_.CoinDual
                            Path                 = Convert-Path $_.Path
                            Arguments            = $_.Arguments
                            Wrap                 = $_.Wrap
                            API                  = $_.API
                            Port                 = $_.Port
                            Types                = $_.Types
                            Profit               = $_.Profit
                            ProfitDual           = $_.ProfitDual
                            Profits              = if ($_.AlgorithmDual -ne $null) {$_.ProfitDual+$_.Profit} else {$_.Profit}
                            HashRate             = [double]$_.HashRate
                            HashRateDual         = [double]$_.HashRateDual
                            Hashrates            = if ($_.AlgorithmDual -ne $null) {(ConvertTo-Hash ($_.HashRate)) + "/s|"+(ConvertTo-Hash $_.HashRateDual) + "/s"} else {(ConvertTo-Hash ($_.HashRate)) +"/s"}
                            PoolAbbName          = $_.PoolAbbName
                            SpeedLive            = 0
                            SpeedLiveDual        = 0
                            ProfitLive           = 0
                            ProfitLiveDual       = 0
                            PoolPrice            = $_.PoolPrice
                            PoolPriceDual        = $_.PoolPriceDual
                            Best                 = $false
                            Process              = $null
                            NewThisRoud          = $True
                            ActiveTime           = [TimeSpan]0
                            LastActiveCheck      = [TimeSpan]0
                            ActivatedTimes       = 0
                            FailedTimes          = 0
                            Status               = ""
                            BenchmarkedTimes     = 0
                            NeedBenchmark        = $false
                            IsValid              = $true
                            PoolWorkers          = $_.PoolWorkers
                            DualMining           = $_.DualMining
                            PoolName             = $_.PoolName
                            Username             = $_.Username
                            WalletMode           = $_.WalletMode
                            Host                 = $_.Host
                            ConfigFileArguments  = $_.ConfigFileArguments
                            GenerateConfigFile   = $_.GenerateConfigFile
                            ConsecutiveZeroSpeed = 0
                            Location             = $_.Location
                            PrelaunchCommand     = $_.PrelaunchCommand

                        }
                        $ActiveMinersIdCounter++
                }
            }

    #update miners that need benchmarks
                                                
    $ActiveMiners | ForEach-Object {

        if ($_.BenchmarkedTimes -lt 4 -and $_.isvalid -and ($_.Hashrate -eq 0 -or ($_.AlgorithmDual -ne $null -and $_.HashrateDual -eq 0)))
            {$_.NeedBenchmark=$true} 
        }

    #For each type, select most profitable miner, not benchmarked has priority
    foreach ($Type in $Types) {

        $BestId=($ActiveMiners |Where-Object IsValid | select-object NeedBenchmark,Profits,Id,Types,Algorithm | where-object {(Compare-Object $Type $_.Types -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | Sort-Object -Descending {if ($_.NeedBenchmark) {1} else {0}}, {$_.Profits},Algorithm | Select-Object -First 1 | Select-Object id)
        $ActiveMiners[$BestId.PSObject.Properties.value].best=$true
        }



    #Stop miners running if they arent best now
    $ActiveMiners | Where-Object Best -EQ $false | ForEach-Object {
        if ($_.Process -eq $null) {
            $_.Status = "Failed"
        }
        elseif ($_.Process.HasExited -eq $false) {
            $_.Process.CloseMainWindow() | Out-Null
            $_.Status = "Idle"
        }
        
        try {$_.Process.CloseMainWindow() | Out-Null} catch {} #security closing
    }
   
    #$ActiveMiners | Where-Object Best -EQ $true  | Out-Host

    Start-Sleep 1 #Wait to prevent BSOD

    #Start all Miners marked as Best

    $ActiveMiners | Where-Object Best -EQ $true | ForEach-Object {
        if ($_.Process -eq $null -or $_.Process.HasExited -ne $false) {

            $_.ActivatedTimes++

            if ($_.GenerateConfigFile -ne $null) {$_.ConfigFileArguments | Set-Content ($_.GenerateConfigFile)}

            #run prelaunch command
            if ($_.PrelaunchCommand -ne "") {Start-Process -FilePath $_.PrelaunchCommand}

            if ($_.Wrap) {$_.Process = Start-Process -FilePath "PowerShell" -ArgumentList "-executionpolicy bypass -command . '$(Convert-Path ".\Wrapper.ps1")' -ControllerProcessID $PID -Id '$($_.Port)' -FilePath '$($_.Path)' -ArgumentList '$($_.Arguments)' -WorkingDirectory '$(Split-Path $_.Path)'" -PassThru}
              else {$_.Process = Start-SubProcess -FilePath $_.Path -ArgumentList $_.Arguments -WorkingDirectory (Split-Path $_.Path)}
          
            if ($_.NeedBenchmark) {$NextInterval=$BechmarkintervalTime} #if one need benchmark next interval will be short

            if ($_.Process -eq $null) {
                    $_.Status = "Failed"
                    $_.FailedTimes++
                } 
            else {
                   $_.Status = "Running"
                   $_.LastActiveCheck=get-date
                }

            }
      
    }


      

         #Call api to local currency conversion
        try {
                $CDKResponse = Invoke-WebRequest "https://api.coindesk.com/v1/bpi/currentprice.json" -UseBasicParsing -TimeoutSec 2 | ConvertFrom-Json | Select-Object -ExpandProperty BPI
                Clear-Host
            } 
                
            catch {
                Clear-Host
                "COINDESK API NOT RESPONDING, NOT POSSIBLE LOCAL COIN CONVERSION" | Out-host 
                }
                
                switch ($location) {
                    'Europe' {$LabelProfit="EUR/Day" ; $localBTCvalue = [double]$CDKResponse.eur.rate}
                    'US'     {$LabelProfit="USD/Day" ; $localBTCvalue = [double]$CDKResponse.usd.rate}
                    'ASIA'   {$LabelProfit="USD/Day" ; $localBTCvalue = [double]$CDKResponse.usd.rate}
                    'GB'     {$LabelProfit="GBP/Day" ; $localBTCvalue = [double]$CDKResponse.gbp.rate}

                }





    $FirstLoopExecution=$True   
    $IntervalStartTime=Get-Date

    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------

    while ($Host.UI.RawUI.KeyAvailable)  {$host.ui.RawUi.Flushinputbuffer()} #keyb buffer flush

    #loop to update info and check if miner is running                        
    While (1 -eq 1) 
        {

        $ExitLoop = $false
        if ($FirstLoopExecution -and $_.NeedBenchmark) {$_.BenchmarkedTimes++}
        Clear-host

        #display interval
        
        $TimetoNextInterval= NEW-TIMESPAN (Get-Date) ($IntervalStartTime.AddSeconds($NextInterval))
        $TimetoNextIntervalSeconds=($TimetoNextInterval.Hours*3600)+($TimetoNextInterval.Minutes*60)+$TimetoNextInterval.Seconds
        if ($TimetoNextIntervalSeconds -lt 0) {$TimetoNextIntervalSeconds = 0}

        Set-ConsolePosition 93 1
        "Next Interval:  $TimetoNextIntervalSeconds secs" | Out-host
        Set-ConsolePosition 0 0

        #display header        
        "-----------------------------------------------------------------------------------------------------------------------"| Out-host
        "  (E)nd Interval   (P)rofits    (C)urrent    (H)istory    (W)allets                       |" | Out-host
        "-----------------------------------------------------------------------------------------------------------------------"| Out-host
        "" | Out-Host
      


        #display current mining info

        "------------------------------------------------ACTIVE MINERS----------------------------------------------------------"| Out-host
  
          $ActiveMiners | Where-Object Status -eq 'Running' | Format-Table -Wrap  (
              @{Label = "Speed"; Expression = {if  ($_.AlgorithmDual -eq $null) {(ConvertTo-Hash  ($_.SpeedLive))+'s'} else {(ConvertTo-Hash  ($_.SpeedLive))+'/s|'+(ConvertTo-Hash ($_.SpeedLiveDual))+'/s'} }; Align = 'right'},     
              @{Label = "BTC/Day"; Expression = {if ($_.NeedBenchmark) {"Benchmarking"} else {$_.ProfitLive.tostring("n5")}}; Align = 'right'}, 
              @{Label = $LabelProfit; Expression = {if ($_.NeedBenchmark) {"Benchmarking"} else {(([double]$_.ProfitLive + [double]$_.ProfitLiveDual) *  [double]$localBTCvalue ).tostring("n2")}}}, 
              @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm} else  {$_.Algorithm+ '|' + $_.AlgorithmDual}}},   
              @{Label = "Coin"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Coin} else  {($_.coin)+ '|' + ($_.CoinDual)}}},   
              @{Label = "Miner"; Expression = {$_.Name}}, 
              @{Label = "Pool"; Expression = {$_.PoolAbbName}},
              @{Label = "Location"; Expression = {$_.Location}},
              @{Label = "PoolWorkers"; Expression = {$_.PoolWorkers}}
          ) | Out-Host
          

        $XToWrite=[ref]0
        $YToWrite=[ref]0      
        Get-ConsolePosition ([ref]$XToWrite) ([ref]$YToWrite)  
        $YToWriteMessages=$YToWrite+1
        $YToWriteData=$YToWrite+2
        Remove-Variable XToWrite
        Remove-Variable YToWrite                          



        #display profits screen
        if ($Screen -eq "Profits") {

                    "----------------------------------------------------PROFITS------------------------------------------------------------"| Out-host            


                    Set-ConsolePosition 80 $YToWriteMessages
                    
                    "(B)est Miners/All       (T)op 40/All" | Out-Host

                    Set-ConsolePosition 0 $YToWriteData


                    if ($ShowBestMinersOnly) {
                        $ProfitMiners=@()
                        $ActiveMiners | Where-Object IsValid |ForEach-Object {
                                           $ExistsBest=$ActiveMiners | Where-Object Algorithm -eq $_.Algorithm | Where-Object AlgorithmDual -eq $_.AlgorithmDual | Where-Object Coin -eq $_.Coin | Where-Object CoinDual -eq $_.CoinDual | Where-Object IsValid -eq $true | Where-Object Profits -gt $_.Profits
                                           if ($ExistsBest -eq $null -or $_.NeedBenchmark -eq $true) {$ProfitMiners += $_}
                                           }
                           }
                    else 
                           {$ProfitMiners=$ActiveMiners}
                    
                           $inserted=1
                           $ProfitMiners2=@()
                            $ProfitMiners | Sort-Object -Descending Type,NeedBenchmark,Profits | ForEach-Object {
                                if ($inserted -le $ProfitsScreenLimit) {$ProfitMiners2+=$_ ; $inserted++} #this can be done with select-object -first but then memory leak happens, ¿why?
                           }
                           

                    #Display profits  information
                    $ProfitMiners2 | Format-Table -GroupBy Type (
                        @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm} else  {$_.Algorithm+ '|' + $_.AlgorithmDual}}},   
                        @{Label = "Coin"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Coin} else  {($_.coin)+ '|' + ($_.CoinDual)}}},   
                        @{Label = "Miner"; Expression = {$_.Name}}, 
                        @{Label = "Speed"; Expression = {if ($_.NeedBenchmark) {"Benchmarking"} else {$_.Hashrates}}}, 
                        @{Label = "BTC/Day"; Expression = {if ($_.NeedBenchmark) {"Benchmarking"} else {$_.Profits.tostring("n5")}}; Align = 'right'}, 
                        @{Label = $LabelProfit; Expression = {([double]$_.Profits * [double]$localBTCvalue ).tostring("n2") } ; Align = 'right'},
                        @{Label = "Pool"; Expression = {$_.PoolAbbName}},
                        @{Label = "Location"; Expression = {$_.Location}}

                    ) | Out-Host


                    Remove-Variable ProfitMiners

                }
  

                
                          
        if ($Screen -eq "Current") {
                    
                    "----------------------------------------------------CURRENT------------------------------------------------------------"| Out-host            
            
                    Set-ConsolePosition 0 $YToWriteData

                    #Display profits  information
                    $ActiveMiners | Where-Object Status -eq 'Running' | Format-Table -Wrap  (
                        @{Label = "Pool"; Expression = {$_.PoolAbb}},
                        @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm} else  {$_.Algorithm+ '|' + $_.AlgorithmDual}}},   
                        @{Label = "Miner"; Expression = {$_.Name}}, 
                        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
                    ) | Out-Host
                    
                    #Nvidia SMI-info
                    if ((Compare-Object "NVIDIA" $types -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0) {
                                $NvidiaCards=@()
                                invoke-expression "./nvidia-smi.exe --query-gpu=gpu_name,driver_version,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed  --format=csv,noheader"  | foreach {
                            
                                        $SMIresultSplit = $_ -split (",")
                                            $NvidiaCards +=[PSCustomObject]@{

                                                        gpu_name           = $SMIresultSplit[0] 
                                                        driver_version     = $SMIresultSplit[1]
                                                        utilization_gpu    = $SMIresultSplit[2]
                                                        utilization_memory = $SMIresultSplit[3]
                                                        temperature_gpu    = $SMIresultSplit[4]
                                                        power_draw         = $SMIresultSplit[5]
                                                        power_limit        = $SMIresultSplit[6]
                                                        FanSpeed           = $SMIresultSplit[7]
                                                    }
                                    }               


                                    $NvidiaCards | Format-Table -Wrap  (
                                        @{Label = "GPU"; Expression = {$_.gpu_name}},
                                        @{Label = "GPU%"; Expression = {$_.utilization_gpu}},   
                                        @{Label = "Mem%"; Expression = {$_.utilization_memory}}, 
                                        @{Label = "Temp"; Expression = {$_.temperature_gpu}}, 
                                        @{Label = "FanSpeed"; Expression = {$_.FanSpeed}},
                                        @{Label = "Power"; Expression = {$_.power_draw+" /"+$_.power_limit}}
                                        
                                    ) | Out-Host


                                }
                }
                                    
                
                    
        if ($Screen -eq "Wallets" -or $FirstTotalExecution -eq $true) {         



            if ($Screen -eq "Wallets") {
                             "----------------------------------------------------WALLETS (slow)-----------------------------------------------------"| Out-host   
                             Set-ConsolePosition 85 $YToWriteMessages
                            "(U)pdate  - $WalletsUpdate  " | Out-Host
                        }


                    if ($WalletsUpdate -eq $null) { #wallets only refresh one time each interval, not each loop iteration

                            $WalletsUpdate=get-date

                            $WalletsToCheck=@()
                            
                            $Pools  | where-object WalletMode -eq 'WALLET' | Select-Object PoolName,AbbName,User,WalletMode -unique  | ForEach-Object {
                                $WalletsToCheck += [PSCustomObject]@{
                                            PoolName   = $_.PoolName
                                            AbbName = $_.AbbName
                                            WalletMode = $_.WalletMode
                                            User       = $_.User
                                            Coin = $null
                                            Algorithm =$null                                      
                                            OriginalAlgorithm =$null
                                            OriginalCoin = $null
                                            Host = $null
                                            Symbol =$null
                                            }
                                }
                            $Pools  | where-object WalletMode -eq 'APIKEY' | Select-Object PoolName,AbbName,info,Algorithm,OriginalAlgorithm,OriginalCoin,Symbol,WalletMode  -unique  | ForEach-Object {
                                $WalletsToCheck += [PSCustomObject]@{
                                            PoolName   = $_.PoolName
                                            AbbName = $_.AbbName
                                            WalletMode = $_.WalletMode
                                            User       = $null
                                            Coin = $_.Info
                                            Algorithm =$_.Algorithm
                                            OriginalAlgorithm =$_.OriginalAlgorithm
                                            OriginalCoin = $_.OriginalCoin
                                            Symbol = $_.Symbol
                                            }
                                }

                            $WalletStatus=@()
                            $WalletsToCheck |ForEach-Object {

                                            Set-ConsolePosition 0 $YToWriteMessages
                                            "                                                                         "| Out-host 
                                            Set-ConsolePosition 0 $YToWriteMessages

                                            if ($_.WalletMode -eq "WALLET") {"Checking "+$_.Abbname+" - "+$_.User | Out-host}
                                                else {"Checking "+$_.Abbname+" - "+$_.coin+' ('+$_.Algorithm+')' | Out-host}
                                          
                                            $Ws = Get-Pools -Querymode $_.WalletMode -PoolsFilterList $_.Poolname -Info ($_)
                                            
                                            if ($_.WalletMode -eq "WALLET") {$Ws | Add-Member Wallet $_.User}
                                            else  {$Ws | Add-Member Wallet $_.Coin}

                                            $Ws | Add-Member PoolName $_.Poolname
                                            
                                            $WalletStatus += $Ws

                                            start-sleep 1 #no saturation of pool api
                                            Set-ConsolePosition 0 $YToWriteMessages
                                            "                                                                         "| Out-host     

                                        } 


                            if ($FirstTotalExecution -eq $true) {$WalletStatusAtStart= $WalletStatus;$FirstTotalExecution=$false}
 
                            $WalletStatus | Add-Member BalanceAtStart [double]$null
                            $WalletStatus | ForEach-Object{
                                    $_.BalanceAtStart = ($WalletStatusAtStart |Where-Object wallet -eq $_.Wallet |Where-Object poolname -eq $_.poolname |Where-Object currency -eq $_.currency).balance
                                    }

                         }


                         if ($Screen -eq "Wallets") {  

                            Set-ConsolePosition 0 $YToWriteData

                            $WalletStatus | where-object Balance -gt 0 | Sort-Object poolname | Format-Table -Wrap -groupby poolname (
                                @{Label = "Wallet"; Expression = {$_.wallet}}, 
                                @{Label = "Currency"; Expression = {$_.currency}}, 
                                @{Label = "Balance"; Expression = {$_.balance.tostring("n5")}; Align = 'right'},
                                @{Label = "IncFromStart"; Expression = {($_.balance - $_.BalanceAtStart).tostring("n5")}; Align = 'right'}
                            ) | Out-Host
                        

                            $Pools  | where-object WalletMode -eq 'NONE' | Select-Object PoolName -unique | ForEach-Object {
                                "NO EXISTS API FOR POOL "+$_.PoolName+" - NO WALLETS CHECK" | Out-host 
                                }  

                            }
                            
                        }

                
        if ($Screen -eq "History") {                        

                    "--------------------------------------------------HISTORY------------------------------------------------------------"| Out-host            

                    Set-ConsolePosition 0 $YToWriteData

                    #Display activated miners list
                    $ActiveMiners | Where-Object ActivatedTimes -GT 0 | Sort-Object -Descending Status, {if ($_.Process -eq $null) {[DateTime]0}else {$_.Process.StartTime}} | Select-Object -First (1 + 6 + 6) | Format-Table -Wrap -GroupBy Status (
                        @{Label = "Speed"; Expression = {if  ($_.AlgorithmDual -eq $null) {(ConvertTo-Hash  ($_.SpeedLive))+'s'} else {(ConvertTo-Hash  ($_.SpeedLive))+'/s|'+(ConvertTo-Hash ($_.SpeedLiveDual))+'/s'} }; Align = 'right'}, 
                        @{Label = "Active"; Expression = {"{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $_.ActiveTime}}, 
                        @{Label = "Launched"; Expression = {Switch ($_.ActivatedTimes) {0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}}, 
                        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
                    ) | Out-Host
                }

  
                 
                   

                $ActiveMiners | Where-Object Best -eq $true | ForEach-Object {
                                $_.SpeedLive = 0
                                $_.SpeedLiveDual = 0
                                $_.ProfitLive = 0
                                $_.ProfitLiveDual = 0
                                $Miner_HashRates = $null


                                if ($_.Process -eq $null -or $_.Process.HasExited) {
                                        if ($_.Status -eq "Running") {
                                                    $_.Status = "Failed"
                                                    $_.FailedTimes++
                                                    $ExitLoop = $true
                                                    }
                                        else
                                            { $ExitLoop = $true}         
                                        }

                                else {
                                        $_.ActiveTime += (get-date) - $_.LastActiveCheck 
                                        $_.LastActiveCheck=get-date

                                        $Miner_HashRates = Get-Live-HashRate $_.API $_.Port 

                                        if ($Miner_HashRates -ne $null){
                                            $_.SpeedLive = [double]($Miner_HashRates[0])
                                            $_.ProfitLive = $_.SpeedLive * $_.PoolPrice 
                                        

                                            if ($Miner_HashRates[0] -gt 0) {$_.ConsecutiveZeroSpeed=0} else {$_.ConsecutiveZeroSpeed++}
                                            
                                                
                                            if ($_.DualMining){     
                                                $_.SpeedLiveDual = [double]($Miner_HashRates[1])
                                                $_.ProfitLiveDual = $_.SpeedLiveDual * $_.PoolPriceDual
                                                }


                                            $Value=[long]($Miner_HashRates[0] * 0.95)

                                            if ($Value -gt $_.Hashrate -and $_.NeedBenchmark) {
                                                $ValueDual=[long]($Miner_HashRates[1] * 0.95)
                                                $_.Hashrate= $Value
                                                $_.HashrateDual= $ValueDual
                                                Set-Hashrates -algorithm $_.Algorithms -minername $_.Name -value  $Value -valueDual $ValueDual
                                                }
                                            }          
                                    }

                                    

                                if ($_.ConsecutiveZeroSpeed -gt 10) { #to prevent miner hangs
                                    $ExitLoop='true'
                                    $_.FailedTimes++
                                    $_.Status='Failed'
                                    }
                
                                        
                                #Benchmark timeout
                                if ($_.BenchmarketTimes -ge 3) {
                                    $_.Status='Cancelled'
                                    $ExitLoop = $true
                                    }

                        }

                    


                $FirstLoopExecution=$False

                #Loop for reading key and wait
                $Loopstart=get-date 
                $KeyPressed=$null    

             
                while ((NEW-TIMESPAN $Loopstart (get-date)).Seconds -lt 4 -and $KeyPressed -ne 'P'-and $KeyPressed -ne 'C'-and $KeyPressed -ne 'H'-and $KeyPressedkey -ne 'E' -and $KeyPressedkey -ne 'W'  -and $KeyPressedkey -ne 'U'  -and $KeyPressedkey -ne 'T' -and $KeyPressedkey -ne 'B'){
                            
                            if ($host.ui.RawUi.KeyAvailable) {
                                        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
                                        $KeyPressed=$Key.character
                                        while ($Host.UI.RawUI.KeyAvailable)  {$host.ui.RawUi.Flushinputbuffer()} #keyb buffer flush
                                        
                                        }
                       }  
                
                switch ($KeyPressed){
                    'P' {$Screen='profits'}
                    'C' {$Screen='current'}
                    'H' {$Screen='history'}
                    'E' {$ExitLoop=$true}
                    'W' {$Screen='Wallets'}
                    'U' {if ($Screen -eq "Wallets") {$WalletsUpdate=$null}}
                    'T' {if ($Screen -eq "Profits") {if ($ProfitsScreenLimit -eq 40) {$ProfitsScreenLimit=1000} else {$ProfitsScreenLimit=40}}}
                    'B' {if ($Screen -eq "Profits") {if ($ShowBestMinersOnly -eq $true) {$ShowBestMinersOnly=$false} else {$ShowBestMinersOnly=$true}}}
                    
                }


           
                if (((Get-Date) -ge ($IntervalStartTime.AddSeconds($NextInterval))) -or ($ExitLoop)  ) {break} #If time of interval has over, exit of main loop

           
    
        }
     
        
    
    Remove-variable miners
    Remove-variable pools
    [GC]::Collect() #force garbage recollector for free memory
   


}

#-----------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------
#-------------------------------------------end of alwais running loop--------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------



#Stop the log
Stop-Transcript
}


function InvokeAs 
{ 
param(
    [Parameter(Mandatory = $true)]
    [Int]$ControllerProcessID, 
    [Parameter(Mandatory = $true)]
    [String]$Id, 
    [Parameter(Mandatory = $true)]
    [String]$FilePath, 
    [Parameter(Mandatory = $false)]
    [String]$ArgumentList = "", 
    [Parameter(Mandatory = $false)]
    [String]$WorkingDirectory = ""
)

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

. .\Include.ps1

#Remove-Item ".\_$Id.txt" -ErrorAction Ignore
0 | Set-Content ".\_$Id.txt"


$PowerShell = [PowerShell]::Create()
if ($WorkingDirectory -ne "") {$PowerShell.AddScript("Set-Location '$WorkingDirectory'") | Out-Null}
$Command = ". '$FilePath'"
if ($ArgumentList -ne "") {$Command += " $ArgumentList"}
$PowerShell.AddScript("$Command 2>&1 | Write-Verbose -Verbose") | Out-Null
$Result = $PowerShell.BeginInvoke()

Write-Host "Wrapper Started" -BackgroundColor Yellow -ForegroundColor Black

do {
    Start-Sleep 1

    $PowerShell.Streams.Verbose.ReadAll() | ForEach-Object {
        $Line = $_

        if ($Line -like "*total speed:*" -or $Line -like "*accepted:*" -or   $Line -like "*Mining on #*"  ) {

#write-host 1111 $Line
#start-sleep 25    
            $Line = $Line -replace "\smh/s","mh/s" -replace "\skh/s","kh/s" -replace "\sgh/s","gh/s" -replace "\sth/s","th/s" -replace "\sph/s","ph/s" -replace "\sh/s"," h/s" 
            $Words = $Line -split " "
            $Word =  $words -like "*/s*" | Select-Object -Last 1
            $HashRate = [Decimal]($Word -replace "mh/s","" -replace "kh/s","" -replace "gh/s","" -replace "th/s","" -replace "ph/s","" -replace "h/s","" )

<#
write-host 3332
$Line | write-host
$Word | write-host
$HashRate | write-host
start-sleep 5
  #>          


            switch  –wildcard ($Word) {
                "*kh/s*" {$HashRate *= [Math]::Pow(1000, 1)}
                "*mh/s*" {$HashRate *= [Math]::Pow(1000, 2)}
                "*gh/s*" {$HashRate *= [Math]::Pow(1000, 3)}
                "*th/s*" {$HashRate *= [Math]::Pow(1000, 4)}
                "*ph/s*" {$HashRate *= [Math]::Pow(1000, 5)}
            }

            $HashRate | Set-Content ".\_$Id.txt"
<#
write-host 4444
$HashRate | write-host
start-sleep 2
#>
            
        }

        $Line
    }

    if ((Get-Process | Where-Object Id -EQ $ControllerProcessID) -eq $null) {$PowerShell.Stop() | Out-Null}
}
until($Result.IsCompleted)

#Remove-Item ".\Wrapper_$Id.txt" -ErrorAction Ignore
}





function Get-Live-HashRate {
    param(
        [Parameter(Mandatory = $true)]
        [String]$API, 
        [Parameter(Mandatory = $true)]
        [Int]$Port, 
        [Parameter(Mandatory = $false)]
        [Object]$Parameters = @{} 
        #[Parameter(Mandatory = $false)]
        #[Bool]$Safe = $false
    )
    
    $Server = "localhost"
    
    $Multiplier = 1000
    #$Delta = 0.05
    #$Interval = 5
    #$HashRates = @()
    #$HashRates_Dual = @()

    try {
        switch ($API) {

            "Dtsm" {

                

                   

                    $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                    $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                    $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                    $Writer.AutoFlush = $true

                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request | ConvertFrom-Json | Select-Object  -ExpandProperty result 

                    $HashRate =  [Double](($Data.sol_ps) | Measure-Object -Sum).Sum
            



                    }
            "xgminer" {
                $Message = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress
            
               
                    $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                    $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                    $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                    $Writer.AutoFlush = $true

                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request.Substring($Request.IndexOf("{"), $Request.LastIndexOf("}") - $Request.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json

                    $HashRate = if ($Data.SUMMARY.HS_5s -ne $null) {[Double]$Data.SUMMARY.HS_5s * [Math]::Pow($Multiplier, 0)}
                    elseif ($Data.SUMMARY.KHS_5s -ne $null) {[Double]$Data.SUMMARY.KHS_5s * [Math]::Pow($Multiplier, 1)}
                    elseif ($Data.SUMMARY.MHS_5s -ne $null) {[Double]$Data.SUMMARY.MHS_5s * [Math]::Pow($Multiplier, 2)}
                    elseif ($Data.SUMMARY.GHS_5s -ne $null) {[Double]$Data.SUMMARY.GHS_5s * [Math]::Pow($Multiplier, 3)}
                    elseif ($Data.SUMMARY.THS_5s -ne $null) {[Double]$Data.SUMMARY.THS_5s * [Math]::Pow($Multiplier, 4)}
                    elseif ($Data.SUMMARY.PHS_5s -ne $null) {[Double]$Data.SUMMARY.PHS_5s * [Math]::Pow($Multiplier, 5)}

                    if ($HashRate -eq $null) {
                            $HashRate = if ($Data.SUMMARY.HS_av -ne $null) {[Double]$Data.SUMMARY.HS_av * [Math]::Pow($Multiplier, 0)}
                            elseif ($Data.SUMMARY.KHS_av -ne $null) {[Double]$Data.SUMMARY.KHS_av * [Math]::Pow($Multiplier, 1)}
                            elseif ($Data.SUMMARY.MHS_av -ne $null) {[Double]$Data.SUMMARY.MHS_av * [Math]::Pow($Multiplier, 2)}
                            elseif ($Data.SUMMARY.GHS_av -ne $null) {[Double]$Data.SUMMARY.GHS_av * [Math]::Pow($Multiplier, 3)}
                            elseif ($Data.SUMMARY.THS_av -ne $null) {[Double]$Data.SUMMARY.THS_av * [Math]::Pow($Multiplier, 4)}
                            elseif ($Data.SUMMARY.PHS_av -ne $null) {[Double]$Data.SUMMARY.PHS_av * [Math]::Pow($Multiplier, 5)}
                            }

            }
            "ccminer" {
                $Message = "summary"


                    $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                    $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                    $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                    $Writer.AutoFlush = $true

                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request -split ";" | ConvertFrom-StringData

                    $HashRate = if ([Double]$Data.KHS -ne 0 -or [Double]$Data.ACC -ne 0) {[Double]$Data.KHS * $Multiplier}

                       



            }
            "nicehashequihash" {
                $Message = "status"

                $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                $Writer.AutoFlush = $true


                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request | ConvertFrom-Json
                
                    $HashRate = $Data.result.speed_hps
                    
                    if ($HashRate -eq $null) {$HashRate = $Data.result.speed_sps}

            }
            "excavator" {
                $Message = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress

                $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                $Writer.AutoFlush = $true


                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = ($Request | ConvertFrom-Json).Algorithms


                    $HashRate = [Double](($Data.workers.speed) | Measure-Object -Sum).Sum

            }
            "ewbf" {
                $Message = @{id = 1; method = "getstat"} | ConvertTo-Json -Compress

                $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                $Writer.AutoFlush = $true


                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request | ConvertFrom-Json
                
                    $HashRate = [Double](($Data.result.speed_sps) | Measure-Object -Sum).Sum
            }
            "claymore" {

                    $Request = Invoke-WebRequest "http://$($Server):$Port" -UseBasicParsing
                    
                    $Data = $Request.Content.Substring($Request.Content.IndexOf("{"), $Request.Content.LastIndexOf("}") - $Request.Content.IndexOf("{") + 1) | ConvertFrom-Json
                    
                    $HashRate = [double]$Data.result[2].Split(";")[0] * $Multiplier
                    $HashRate_Dual = [double]$Data.result[4].Split(";")[0] * $Multiplier




            }

            "ClaymoreV2" {
                
                                    $Request = Invoke-WebRequest "http://$($Server):$Port" -UseBasicParsing
                                    
                                    $Data = $Request.Content.Substring($Request.Content.IndexOf("{"), $Request.Content.LastIndexOf("}") - $Request.Content.IndexOf("{") + 1) | ConvertFrom-Json
                                    
                                    $HashRate = [double]$Data.result[2].Split(";")[0] 

                            }

            "prospector" {
                    $Request = Invoke-WebRequest "http://$($Server):$Port/api/v0/hashrates" -UseBasicParsing
                    $Data = $Request | ConvertFrom-Json
                    $HashRate =  [Double]($Data.rate | Measure-Object -Sum).sum
                 }

            "fireice" {
                
                    $Request = Invoke-WebRequest "http://$($Server):$Port/h" -UseBasicParsing
                    
                    $Data = $Request.Content -split "</tr>" -match "total*" -split "<td>" -replace "<[^>]*>", ""
                    
                    $HashRate = $Data[1]
                    if ($HashRate -eq "") {$HashRate = $Data[2]}
                    if ($HashRate -eq "") {$HashRate = $Data[3]}

                    
            }
            "wrapper" {
                    $HashRate = ""
                    $HashRate = Get-Content ".\Wrapper_$Port.txt"
                    $HashRate =  $HashRate -replace ',','.'



                }
        }

        $HashRates=@()
        $HashRates += [double]$HashRate
        $HashRates += [double]$HashRate_Dual

        $HashRates
    }
    catch {
    }
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function ConvertTo-Hash { 
    param(
        [Parameter(Mandatory = $true)]
        [double]$Hash
         )

    
    $Return=switch ([math]::truncate([math]::log($Hash, [Math]::Pow(1000, 1)))) {
                0 {"{0:n2}  H" -f ($Hash / [Math]::Pow(1000, 0))}
                1 {"{0:n2} KH" -f ($Hash / [Math]::Pow(1000, 1))}
                2 {"{0:n2} MH" -f ($Hash / [Math]::Pow(1000, 2))}
                3 {"{0:n2} GH" -f ($Hash / [Math]::Pow(1000, 3))}
                4 {"{0:n2} TH" -f ($Hash / [Math]::Pow(1000, 4))}
                Default {"{0:n2} PH" -f ($Hash / [Math]::Pow(1000, 5))}
        }
    $Return
}




#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Start-SubProcess {
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = ""
    )

    $Job = Start-Job -ArgumentList $PID, $FilePath, $ArgumentList, $WorkingDirectory {
        param($ControllerProcessID, $FilePath, $ArgumentList, $WorkingDirectory)

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if ($ControllerProcess -eq $null) {return}

        $ProcessParam = @{}
        $ProcessParam.Add("FilePath", $FilePath)
        $ProcessParam.Add("WindowStyle", 'Minimized')
        if ($ArgumentList -ne "") {$ProcessParam.Add("ArgumentList", $ArgumentList)}
        if ($WorkingDirectory -ne "") {$ProcessParam.Add("WorkingDirectory", $WorkingDirectory)}
        $Process = Start-Process @ProcessParam -PassThru
        if ($Process -eq $null) {
            [PSCustomObject]@{ProcessId = $null}
            return        
        }

        [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}
        
        $ControllerProcess.Handle | Out-Null
        $Process.Handle | Out-Null

        do {if ($ControllerProcess.WaitForExit(1000)) {$Process.CloseMainWindow() | Out-Null}}
        while ($Process.HasExited -eq $false)
    }

    do {Start-Sleep 1; $JobOutput = Receive-Job $Job}
    while ($JobOutput -eq $null)

    $Process = Get-Process | Where-Object Id -EQ $JobOutput.ProcessId
    $Process.Handle | Out-Null
    $Process
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Expand-WebRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Uri, 
        [Parameter(Mandatory = $true)]
        [String]$Path
    )

    
    $DestinationFolder = $PSScriptRoot + $Path.Substring(1)
    $FileName = ([IO.FileInfo](Split-Path $Uri -Leaf)).name
    $FilePath = $PSScriptRoot +'\'+$Filename


    if (Test-Path $FileName) {Remove-Item $FileName}


    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing
    
    $Command='x "'+$FilePath+'" -o"'+$DestinationFolder+'" -y -spe'
    Start-Process "7z" $Command -Wait

    if (Test-Path $FileName) {Remove-Item $FileName}
    
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Get-Pools {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Querymode = 'core', 
        [Parameter(Mandatory = $false)]
        [array]$PoolsFilterList=$null,
        #[array]$PoolsFilterList='Mining_pool_hub',
        [Parameter(Mandatory = $false)]
        [array]$CoinFilterList,
        #[array]$CoinFilterList = ('GroestlCoin','Feathercoin','zclassic'),
        [Parameter(Mandatory = $false)]
        [string]$Location=$null,
        #[string]$Location='EUROPE'
        [Parameter(Mandatory = $false)]
        [array]$AlgoFilterList,
        [Parameter(Mandatory = $false)]
        [pscustomobject]$Info
        )
        #in detail mode returns a line for each pool/algo/coin combination, in info mode returns a line for pool

        if ($location -eq 'GB') {$location='EUROPE'}

        $PoolsFolderContent= Get-ChildItem ($PSScriptRoot+'\pools') | Where-Object {$PoolsFilterList.Count -eq 0 -or (Compare $PoolsFilterList $_.BaseName -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0}
        
            $ChildItems=@()

            if ($info -eq $null) {$Info=[pscustomobject]@{}}

            if (($info |  Get-Member -MemberType NoteProperty | where-object name -eq location) -eq $null) {$info | Add-Member Location $Location}

            $PoolsFolderContent | ForEach-Object {
                                    $Name = $_.BaseName
                                    $SharedFile="$PSScriptRoot\$Name.tmp"
                                    if (Test-Path $SharedFile) {Remove-Item $SharedFile}
                                    &$_.FullName -Querymode $Querymode -Info $Info
                                    if (Test-Path $SharedFile) {
                                            $Content=Get-Content $SharedFile | ConvertFrom-Json 
                                            Remove-Item $SharedFile
                                        }
                                    $Content | ForEach-Object {$ChildItems +=[PSCustomObject]@{Name = $Name; Content = $_}}
                                    }
                                
         

            $AllPools = $ChildItems | ForEach-Object {if ($_.content -ne $null) {$_.Content | Add-Member @{Name = $_.Name} -PassThru -Force}}
               

            $AllPools | Add-Member LocationPriority 9999

            #Apply filters
            $AllPools2=@()
            if ($Querymode -eq "core" -or $Querymode -eq "menu" ){
                        foreach ($Pool in $AllPools){
                                #must have wallet
                                if ($Pool.user -ne $null) {
                                    
                                    #must be in algo filter list or no list
                                    if ($AlgoFilterList -ne $null) {$Algofilter = compare-object $AlgoFilterList $Pool.Algorithm -IncludeEqual -ExcludeDifferent}
                                    if (($AlgoFilterList.count -eq 0) -or ($Algofilter -ne $null)){
                                       
                                            #must be in coin filter list or no list
                                            if ($CoinFilterList -ne $null) {$Coinfilter = compare-object $CoinFilterList $Pool.info -IncludeEqual -ExcludeDifferent}
                                            if (($CoinFilterList.count -eq 0) -or ($Coinfilter -ne $null)){
                                                if ($pool.location -eq $Location) {$Pool.LocationPriority=1}
                                                if (($pool.location -eq 'EU') -and ($location -eq 'US')) {$Pool.LocationPriority=2}
                                                if (($pool.location -eq 'EUROPE') -and ($location -eq 'US')) {$Pool.LocationPriority=2}
                                                if ($pool.location -eq 'US' -and $location -eq 'EUROPE') {$Pool.LocationPriority=2}
                                                if ($pool.location -eq 'US' -and $location -eq 'EU') {$Pool.LocationPriority=2}
                                                if ($Pool.Info -eq $null) {$Pool.info=''}
                                                $AllPools2+=$Pool
                                                }
                                        
                                    }
                        }
                        
                        }
                        #Insert by priority of location
                        if ($Location -ne "") {
                                $Return=@()
                                $AllPools2 | Sort-Object Info,Algorithm,LocationPriority | ForEach-Object {
                                    $Ex = $Return | Where-Object Info -eq $_.Info | Where-Object Algorithm -eq $_.Algorithm
                                    if ($Ex.count -eq 0) {$Return += $_}
                                    }
                            }
                        else {
                             $Return=$AllPools2
                            }
                }
            else 
             { $Return= $AllPools }


    
    Remove-variable ChildItems
    Remove-variable AllPools
    Remove-variable AllPools2
    
    $Return     
    

 }

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

 
function Get-Best-Hashrate-Algo {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm
    )


    $Pattern="*_"+$Algorithm+"_HashRate.txt"

    $Besthashrate=0

    Get-ChildItem ($PSScriptRoot+"\Stats")  | Where-Object pschildname -like $Pattern | ForEach-Object {
              $Content= ($_ | Get-Content | ConvertFrom-Json)
              $Hrs=0
              if ($content -ne $null) {$Hrs = [double]($Content[0])}

              if ($Hrs -gt $Besthashrate) {
                      $Besthashrate=$Hrs
                      $Miner= ($_.pschildname -split '_')[0]
                      }
            $Return=[pscustomobject]@{
                            Hashrate=$Besthashrate
                            Miner=$Miner
                          }

      }

    $Return
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Get-Algo-Divisor {
      param(
        [Parameter(Mandatory = $true)]
        [String]$Algo
            )

                    $Divisor = 1000000000
                    
                    switch($Algo)
                    {
                        "skein"{$Divisor *= 100}
                        "equihash"{$Divisor /= 1000}
                        "blake2s"{$Divisor *= 1000}
                        "blakecoin"{$Divisor *= 1000}
                        "decred"{$Divisor *= 1000}
                        "blake14r"{$Divisor *= 1000}
                    }

    $Divisor
     }


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function set-ConsolePosition ([int]$x,[int]$y) { 
        # Get current cursor position and store away 
        $position=$host.ui.rawui.cursorposition 
        # Store new X Co-ordinate away 
        $position.x=$x
        $position.y=$y
        # Place modified location back to $HOST 
        $host.ui.rawui.cursorposition=$position
        remove-variable position
        }

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get-ConsolePosition ([ref]$x,[ref]$y) { 

    $position=$host.ui.rawui.cursorposition 
    $x.value=$position.x
    $y.value=$position.y
    remove-variable position

}
        

   
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function set-WindowSize ([int]$Width,[int]$Height) { 
    #zero not change this axis
    $pshost = Get-Host
    $psWindow = $pshost.UI.RawUI
    $newSize = $psWindow.WindowSize
    if ($Width -ne 0) {$newSize.Width =$Width}
    if ($Height -ne 0) {$newSize.Height =$Height}
    $psWindow.WindowSize= $newSize
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function get-algo-unified-name ([string]$Algo) {

    $Result=$Algo
    switch ($Algo){
            "sib" {$Result="x11gost"}
            "Blake (14r)" {$Result="Blake14r"} 
            "Blake (2b)" {$Result="Blake2b"} 
            "decred" {$Result="Blake14r"}
            "Lyra2RE2" {$Result="lyra2v2"}
            "Lyra2REv2" {$Result="lyra2v2"}
            "sia" {$Result="Blake2b"}
            "myr-gr" {$Result="Myriad-Groestl"}
            "myriadgroestl" {$Result="Myriad-Groestl"}
            "daggerhashimoto" {$Result="Ethash"}
            "dagger" {$Result="Ethash"}
            "hashimoto" {$Result="Ethash"}
            "skunkhash" {$Result="skunk"}
            }        
     $Result       

}

 #************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

                    
function get-coin-unified-name ([string]$Coin) {

    $Result = $Coin
    switch –wildcard  ($Coin){
            "Myriadcoin-*" {$Result="Myriad"}
            "Myriad-*" {$Result="Myriad"}
            "Dgb-*" {$Result="Digibyte"}
            "Digibyte-*" {$Result="Digibyte"}
            "Verge-*" {$Result="Verge"}
            "EthereumClassic" {$Result="Ethereum-Classic"}
            }      
          
     $Result       

}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function Get-Hashrates  {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName

    )


    $Pattern=$MinerName+"_"+$Algorithm+"_HashRate.txt"

    try {$Content=(Get-ChildItem ($PSScriptRoot+"\Stats")  | Where-Object pschildname -eq $Pattern | Get-Content | ConvertFrom-Json)} catch {$Content=$null}
    
    if ($content -ne $null) {$Hrs = $Content[0].tostring() + "_" + $Content[1].tostring()}

    $Hrs

}
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Set-Hashrates {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [long]$Value,
        [Parameter(Mandatory = $true)]
        [long]$ValueDual
        
    )


    $Path=$PSScriptRoot+"\Stats\"+$MinerName+"_"+$Algorithm+"_HashRate.txt"

    $Array=$Value,$valueDual
    $Array | Convertto-Json | Set-Content  -Path $Path
    Remove-Variable Array

    
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function Start-Downloader {
    param(
    [Parameter(Mandatory = $true)]
    [String]$URI,
    [Parameter(Mandatory = $true)]
    [String]$ExtractionPath,
    [Parameter(Mandatory = $true)]
    [String]$Path
     )


        if (-not (Test-Path $Path)) {
            try {


                if ($URI -and (Split-Path $URI -Leaf) -eq (Split-Path $Path -Leaf)) {
                    New-Item (Split-Path $Path) -ItemType "Directory" | Out-Null
                    Invoke-WebRequest $URI -OutFile $Path -UseBasicParsing -ErrorAction Stop
                }
                else {
                    Clear-Host
                    Write-Host -BackgroundColor green -ForegroundColor Black "Downloading....$($URI)"
                    Expand-WebRequest $URI $ExtractionPath -ErrorAction Stop
                }
            }
            catch {
                
                if ($URI) {Write-Host -BackgroundColor Yellow -ForegroundColor Black "Cannot download $($Path) distributed at $($URI). "}
                else {Write-Host -BackgroundColor Yellow -ForegroundColor Black "Cannot download $($Path). "}
                
                
                if ($Path_Old) {
                    if (Test-Path (Split-Path $Path_New)) {(Split-Path $Path_New) | Remove-Item -Recurse -Force}
                    (Split-Path $Path_Old) | Copy-Item -Destination (Split-Path $Path_New) -Recurse -Force
                }
                else {
                    if ($URI) {Write-Host -BackgroundColor Yellow -ForegroundColor Black "Cannot find $($Path) distributed at $($URI). "}
                    else {Write-Host -BackgroundColor Yellow -ForegroundColor Black "Cannot find $($Path). "}
                }
            }
        }
    

    
}




#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function clear-log{

    $Now = Get-Date
    $Days = "3"

    $TargetFolder = ".\Logs"
    $Extension = "*.txt"
    $LastWrite = $Now.AddDays(-$Days)

    $Files = Get-Childitem $TargetFolder -Include $Extension -Recurse | Where-Object {$_.LastWriteTime -le "$LastWrite"}

    $Files |ForEach-Object {Remove-Item $_.fullname}

}
