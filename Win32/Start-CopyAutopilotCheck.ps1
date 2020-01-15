<# 
   .SYNOPSIS 
    Sets up the Autopilot check and timings functions

   .DESCRIPTION
    This application will copy setup files to destination outlined in the variables section.  
    It will then create a schedule task to trigger the checks from that location.  Installs 
    BurntToast module as part if the installation process https://github.com/Windos/BurntToast

   .EXAMPLE
    .\Start-CopyAutopilotCheck.ps1 
    Starts the prestage and schedule task creation process


   .PARAMETER DownloadMode
    There are no parameters for this

   .INPUTS
    There are no additional inputs for this script outside of the parameters

   .OUTPUTS
    A log file will be created

   .NOTES
    AUTHOR: Chris Roberts (I071882)
    EMAIL: chris.roberts@sap.com
    VERSION: 0.9.0.0
    DATE: 05/07/2019
    
    CHANGE LOG: 
        0.9.0.0 : 05/02/2019 : Initial version
        1.0.0.0 : 09/07/2019 : Release version with change of keys to Prov over OSD 
        1.1.0.0 : 14/01/2020 : Added Prestage on Switch

   .LINK
    https://github.com/Windos/BurntToast
#> 
Param( 
[switch]$PreStageOnly  
)

$ScriptVer = "1.1.0.0"
$ExecuteDate = Get-Date

# Change the variables below for different options in your environment
$LogFile = "$env:SystemDrive\Users\Public\AutopilotCheck.log"
$DestSource = 'C:\Program Files\AutopilotCheck'
$TaskName = "Autopilot Check"

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

#------------------------------------------------------------
# Function will Prestage all the content to the local system
#------------------------------------------------------------
function Start-Prestage
{
    Log-ScriptEvent $LogFile "Starting Copying Autopilot check files" "Autopilot_Install" 1 
    $CopySource = $PSScriptRoot
    Log-ScriptEvent $LogFile "Source files for process : $CopySource" "Autopilot_Install" 1 
    Log-ScriptEvent $LogFile "Destination folder for process : $DestSource" "Autopilot_Install" 1 
    Log-ScriptEvent $LogFile "Starting Copy process" "Autopilot_Install" 1

    $ModuleDest = "C:\Program Files\WindowsPowerShell\Modules"
    Copy-Item -Path $CopySource\* -Destination $DestSource -force

    Log-ScriptEvent $LogFile "Setting up Burnt Toast for notifications" "Autopilot_Install" 1

    # Block this line out if you don't want to install modules
    Install-Module -Name BurntToast -Force

    <# UNBLOCK THIS CODE IF YOU DON'T LIKE USING MODULES
    Copy-Item -Path $CopySource\BurntToast -Destination $ModuleDest -Recurse -force
    #>
}
#--------------
# End function
#--------------

#--------------------
# Start of main body
#--------------------
Check-Logfile $LogFile
Log-ScriptEvent $LogFile "================================" "Autopilot_Install" 1 
Log-ScriptEvent $LogFile "Start Installing Autopilot Check" "Autopilot_Install" 1 
Log-ScriptEvent $LogFile "================================" "Autopilot_Install" 1 
Log-ScriptEvent $LogFile "Script version : $ScriptVer" "Autopilot_Install" 1 
Log-ScriptEvent $LogFile "Script run date and time : $ExecuteDate" "Autopilot_Install" 1 

Start-Prestage
Log-ScriptEvent $LogFile "Setup $TaskName" "Autopilot_Install" 1 

If($PreStageOnly)
{
    Log-ScriptEvent $LogFile "Prestage Only - not adding schedule task to system" "Autopilot_Install" 1     
}
else
    {
    Log-ScriptEvent $LogFile "Check if schedule task already exists" "Autopilot_Install" 1 
    if(!(Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue))
    {
        Log-ScriptEvent $LogFile "$TaskName does not exists, creating task" "Autopilot_Install" 1 
        Register-ScheduledTask -xml (get-content "$DestSource\Autopilot_SchedTask.xml" | out-string) -TaskName $TaskName
    
    }
    else
    {
        Log-ScriptEvent $LogFile "$TaskName already exists" "Autopilot_Install" 2 
    }
}
Log-ScriptEvent $LogFile "Autopilot check files and task created" "Autopilot_Install" 1 