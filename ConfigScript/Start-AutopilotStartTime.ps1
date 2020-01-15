<# 
   .SYNOPSIS 
    Sets the Autopilot Start Time and additional keys needed by AutoPilot Check

   .DESCRIPTION
    Sets the Autopilot Start Time and additional keys needed by AutoPilot Check.  This should be setup as a
    Intune Configuration Powershell Script in Intune.  For more details see the Readme

   .EXAMPLE
    .\Start-AutopilotStartTime.ps1 
    Starts the installation process


   .PARAMETER DownloadMode
    There are no parameters for this

   .INPUTS
    There are no additional inputs for this script outside of the parameters

   .OUTPUTS
    The are no additional outputs for this script

   .NOTES
    AUTHOR: Chris Roberts (I071882)
    EMAIL: chris.roberts@sap.com
    VERSION: 1.0.0.0
    DATE: 15/01/2020 
    
    CHANGE LOG: 
        1.0.0.0 : 25/07/2019 : Initial version

   .LINK
    
#> 
$ScriptVer = "1.0.0.0"
$ExecuteDate = Get-Date

# Change the variables below for different options in your environment
$LogFile = "$env:SystemDrive\Users\Public\AutopilotCheck.log"
$RegLoc = "HKLM:\SOFTWARE\AutopilotCheck"

#------------------------------------------
# Function for CMTrace Conmpatible logging
#------------------------------------------
Function Log-ScriptEvent { 
 
#Define and validate parameters 
[CmdletBinding()] 
Param( 
      #Path to the log file 
      [parameter(Mandatory=$True)] 
      [String]$NewLog, 
 
      #The information to log 
      [parameter(Mandatory=$True)] 
      [String]$Value, 
 
      #The source of the error 
      [parameter(Mandatory=$True)] 
      [String]$Component, 
 
      #The severity (1 - Information, 2- Warning, 3 - Error) 
      [parameter(Mandatory=$True)] 
      [ValidateRange(1,3)] 
      [Single]$Severity 
      ) 
 
 
#Obtain UTC offset 
$DateTime = New-Object -ComObject WbemScripting.SWbemDateTime  
$DateTime.SetVarDate($(Get-Date)) 
$UtcValue = $DateTime.Value 
$UtcOffset = $UtcValue.Substring(21, $UtcValue.Length - 21) 
 
#Create the line to be logged 
$LogLine =  "<![LOG[$Value]LOG]!>" + "<time=`"$(Get-Date -Format HH:mm:ss.fff)$($UtcOffset)`" " + "date=`"$(Get-Date -Format M-d-yyyy)`" " + "component=`"$Component`" " + "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " + "type=`"$Severity`" " + "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " + "file=`"`">" 

#Write the line to the passed log file 
Add-Content -Path $NewLog -Value $LogLine 
 
}  
#--------------
# End function
#--------------

#---------------------------------------------------------
# Function to check log file and rename if already exists
#---------------------------------------------------------
function Check-Logfile ($InputFile)
{
    if (Test-Path ($InputFile))
    {
        # Only change logfile when size exceeds 1MB
        if ((Get-Item $InputFile).Length -gt 100KB)        
        {
            if (Test-Path ($InputFile -replace ".log",".lo_"))
            {
                Remove-Item ($InputFile -replace ".log",".lo_")
            }
            Rename-Item $InputFile ($InputFile -replace ".log",".lo_")
        }
    }
    elseif ((Test-Path C:\Users\Public\SAP-IT\PackageLogs) -eq $false)
    {
        New-Item -path C:\Users\Public\SAP-IT\PackageLogs -ItemType Directory
    }
}
#--------------
# End function
#--------------

#--------------------
# Start of main body
#--------------------
Check-Logfile $LogFile
Log-ScriptEvent $LogFile "================================" "Autopilot_Initialization" 1 
Log-ScriptEvent $LogFile "Autopilot Check Start Time Setup" "Autopilot_Initialization" 1 
Log-ScriptEvent $LogFile "================================" "Autopilot_Initialization" 1 
Log-ScriptEvent $LogFile "Script version : $ScriptVer" "Autopilot_Initialization" 1 
Log-ScriptEvent $LogFile "Script run date and time : $ExecuteDate" "Autopilot_Initialization" 1 

# Only set the start time once
Log-ScriptEvent $LogFile "Check if Prov start time exists" "Autopilot_Initialization" 1 

if(!(Get-ItemProperty -Path $RegLoc -Name ProvStartTime -ErrorAction SilentlyContinue))
{
    Log-ScriptEvent $LogFile "Setting Prov Start time regkey from Internet API" "Autopilot_Initialization" 1 

    # Use Worldtimeapi to get the REAL time
    $time1 = (Invoke-RestMethod -Uri ‘http://worldtimeapi.org/api/timezone/Etc/GMT’ -Method GET).utc_datetime -replace "T"," " -replace "-","/"
    $StartTime = $time1.Substring(0, $time1.IndexOf('.')) 

    Log-ScriptEvent $LogFile "Setting Prov Start time as $StartTime" "Autopilot_Initialization" 1
    
    if(!(Get-Item -Path $RegLoc -ErrorAction SilentlyContinue))
    {
        New-Item -Path $RegLoc -Force -ErrorAction SilentlyContinue
    }

    $NetworkInfo = Get-NetConnectionProfile
    $NetIPAddress = (Get-NetConnectionProfile | Get-NetIPAddress -AddressFamily IPv4).IPAddress

    New-ItemProperty -Path $RegLoc -Name ProvStartTime -PropertyType String -Value $StartTime  -Force -ErrorAction SilentlyContinue   
    New-ItemProperty -Path $RegLoc -Name ProvStatus -Value "New" -PropertyType String -Force -ErrorAction SilentlyContinue
    New-ItemProperty -Path $RegLoc -Name ProvAppScore -Value 0 -PropertyType String -Force -ErrorAction SilentlyContinue 
    New-ItemProperty -Path $RegLoc -Name ProvSSID -Value $NetworkInfo.Name -PropertyType String -Force -ErrorAction SilentlyContinue 
    New-ItemProperty -Path $RegLoc -Name ProvNetType -Value $NetworkInfo.InterfaceAlias -PropertyType String -Force -ErrorAction SilentlyContinue 
    New-ItemProperty -Path $RegLoc -Name ProvIPAddress -Value $NetIPAddress -PropertyType String -Force -ErrorAction SilentlyContinue 


}
