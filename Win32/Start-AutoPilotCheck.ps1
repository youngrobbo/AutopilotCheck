<# 
   .SYNOPSIS 
    Runs a check of the Autopilot process

   .DESCRIPTION
    This application check the Autopilot process via a Scheduled Task on the client

   .EXAMPLE
    .\Start-AutopilotCheck.ps1 
    Starts the process


   .PARAMETER DownloadMode
    There are no parameters for this

   .INPUTS
    There are no additional inputs for this script outside of the parameters

   .OUTPUTS
    The are no additional outputs for this script

   .NOTES
    AUTHOR: Chris Roberts (I071882)
    EMAIL: chris.roberts@sap.com
    VERSION: 2.2.2.0
    DATE: 23/12/2019
    
    CHANGE LOG: 
        2.0.0.0 : 23/12/2019 : New version using XML as basis - a Christmas Present :)
        2.0.0.1 : 06/01/2020 : Released to DEV ring version - renamed XML file to prevent confusion with Sched Task
        2.0.1.1 : 06/01/2020 : Issue with location for XML file
        2.0.2.0 : 06/01/2020 : Changed log file not found to be not installed message
        2.1.0.0 : 07/01/2020 : Added function and checks for Windows Store Apps
        2.1.0.1 : 07/01/2020 : Removed extra log entry for appscore if device hasn't completed
        2.2.0.0 : 07/01/2020 : Changed getting times from local system to Internet API service
        2.2.1.0 : 08/01/2020 : Added get local time to top of script - can be used to check time shifts
        2.2.2.0 : 09/01/2020 : Changed to use Get-Package at advice of BY
        2.2.2.1 : 09/01/2010 : Issue with end date not being logged - wrong string referenced
        2.3.0.0 : 09/01/2020 : Removed all WMI call for Products and Win32's - now uses Get-Package

   .LINK
    JAM Page link to be added for update
#>

$ScriptVer = "2.3.0.0"
$ExecuteDate = (Get-Date).ToString('yyyy/MM/dd HH:mm:ss')

# Change the variables below for different options in your environment
$LogFile = "$env:SystemDrive\Users\Public\AutopilotCheck.log"
$TaskName = "Autopilot Check"
$RegLoc = 'HKLM:\SOFTWARE\AutopilotCheck'
$DestSource = 'C:\Program Files\AutopilotCheck'
$XMLFile = "$DestSource\ApplicationsCheck.xml"

#------------------------------------------
# Function for CMTrace Compatible logging
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
}
#--------------
# End function
#--------------

#============================================================
# Checks the installation using the installed products class
#============================================================
function Check-InstalledProduct
{
[CmdletBinding()] 
Param( 
      #Application Name to find
      [parameter(Mandatory=$True)] 
      [String]$ApplicationName,
      [parameter(Mandatory=$True)] 
      [Int]$AppScore,
      [parameter(Mandatory=$True)] 
      [String]$DisplayName
)
    $Output = $InstalledProducts.Name -match $ApplicationName
    if($Output)
    {
        Log-ScriptEvent $LogFile "$DisplayName : Installed" "Autopilot_Checks" 1 
        Return $AppScore
    }
    else
    {
        Log-ScriptEvent $LogFile "$DisplayName : Not Installed" "Autopilot_Checks" 2 
        Return 0
    }
}
#==============
# Function end
#==============


#================================================================
# Checks the installation log file from any location for a string
#================================================================
Function Check-InstalledLogFile
{
[CmdletBinding()] 
Param( 
      #Application Name to find
      [parameter(Mandatory=$True)] 
      [String]$CheckFile,
      [parameter(Mandatory=$True)] 
      [String]$StringtoMatch,
      [parameter(Mandatory=$True)] 
      [Int]$AppScore,
      [parameter(Mandatory=$True)] 
      [String]$DisplayName
)

    If (Test-Path $CheckFile)
    {
        if(Select-String -Path $CheckFile -Pattern $StringtoMatch -SimpleMatch)
        {
            Log-ScriptEvent $LogFile "$DisplayName : Installed" "Autopilot_Checks" 1 
            Return $AppScore
        }
        else
        {
            Log-ScriptEvent $LogFile "$DisplayName : Not Installed" "Autopilot_Checks" 2     
            Return 0
        }
    }
    else
    {
        Log-ScriptEvent $LogFile "$DisplayName : Not installed" "Autopilot_Checks" 2     
        Return 0        
    }
}
#=============
# End Function
#=============

#============================================================
# Checks the installation from Windows Store using WMI class
#============================================================
function Check-WindowsStore
{
[CmdletBinding()] 
Param( 
      #Application Name to find
      [parameter(Mandatory=$True)] 
      [String]$ApplicationName,
      [parameter(Mandatory=$True)] 
      [Int]$AppScore,
      [parameter(Mandatory=$True)] 
      [String]$DisplayName
)
    # Store WMI query is fast so no need to use array preloaded
    $Output = Get-WmiObject -Class Win32_InstalledStoreProgram | where name -eq $ApplicationName
    if($Output)
    {
        Log-ScriptEvent $LogFile "$DisplayName : Installed" "Autopilot_Checks" 1 
        Return $AppScore
    }
    else
    {
        Log-ScriptEvent $LogFile "$DisplayName : Not Installed" "Autopilot_Checks" 2 
        Return 0
    }
}
#==============
# Function end
#==============

#--------------------
# Start of main body
#--------------------
Check-Logfile $LogFile

#Set Appscore to Zero to start
$TotalAppScore = 0

Log-ScriptEvent $LogFile "==========================================================" "Autopilot_Checks" 1 
Log-ScriptEvent $LogFile "*** Schedule Task Executed to Check Autopilot progress ***" "Autopilot_Checks" 1 
Log-ScriptEvent $LogFile "==========================================================" "Autopilot_Checks" 1 
Log-ScriptEvent $LogFile "Script version : $ScriptVer" "Autopilot_Checks" 1 
Log-ScriptEvent $LogFile "Script run local client date and time : $ExecuteDate" "Autopilot_Checks" 1 

# Capture network information
$NetworkInfo = Get-NetConnectionProfile
$NetIPAddress = (Get-NetConnectionProfile | Get-NetIPAddress -AddressFamily IPv4).IPAddress
$time1 = (Invoke-RestMethod -Uri ‘http://worldtimeapi.org/api/timezone/Etc/GMT’ -Method GET).utc_datetime -replace "T"," " -replace "-","/"
$CurrentDate = $time1.Substring(0, $time1.IndexOf('.')) 

# Added check to make sure start time exists, if not create all keys - version 1.2.0.0
Log-ScriptEvent $LogFile "Check if Start Time exists" "Autopilot_Checks" 1 

if(!(Get-ItemProperty -Path $RegLoc -Name ProvStartTime -ErrorAction SilentlyContinue))
{
    Log-ScriptEvent $LogFile "Start time does not exist - creating keys" "Autopilot_Checks" 1 
    Log-ScriptEvent $LogFile "Setting Prov Start time regkey" "Autopilot_Checks" 1 
    Log-ScriptEvent $LogFile "Setting Prov Start time as $CurrentDate" "Autopilot_Checks" 1
    
    if(!(Get-Item -Path $RegLoc -ErrorAction SilentlyContinue))
    {
        New-Item -Path $RegLoc -Force -ErrorAction SilentlyContinue
    }

    New-ItemProperty -Path $RegLoc -Name ProvStartTime -PropertyType String -Value $CurrentDate  -Force -ErrorAction SilentlyContinue   
    New-ItemProperty -Path $RegLoc -Name ProvStatus -Value "New" -PropertyType String -Force -ErrorAction SilentlyContinue
    New-ItemProperty -Path $RegLoc -Name ProvAppScore -Value 0 -PropertyType String -Force -ErrorAction SilentlyContinue 
    New-ItemProperty -Path $RegLoc -Name ProvSSID -Value $NetworkInfo.Name -PropertyType String -Force -ErrorAction SilentlyContinue 
    New-ItemProperty -Path $RegLoc -Name ProvNetType -Value $NetworkInfo.InterfaceAlias -PropertyType String -Force -ErrorAction SilentlyContinue 
    New-ItemProperty -Path $RegLoc -Name ProvIPAddress -Value $NetIPAddress -PropertyType String -Force -ErrorAction SilentlyContinue 

}

# Added check for IME running - version 1.2.0.0
Log-ScriptEvent $LogFile "Checking status of Intune Management Extension Engine" "Autopilot_Checks" 1 
if ((Get-Service -Name IntuneManagementExtension).Status -ne "Running")
{
    Log-ScriptEvent $LogFile "IME not started - attempting to start service now" "Autopilot_Checks" 3 
    Start-Service -Name IntuneManagementExtension
}
else
{
    Log-ScriptEvent $LogFile "IME already running" "Autopilot_Checks" 1 
}

# Status new check - if status = new then run the following - version 1.4.0.0
if((Get-ItemProperty -Path $RegLoc).ProvStatus -eq "New")
{
    # Check network hasn't changed mid-provision
    if((Get-ItemProperty -Path $RegLoc).ProvSSID -ne $NetworkInfo.Name)
    {
        Log-ScriptEvent $LogFile "Network SSID has changed mid-provision - recording new network settings" "Autopilot_Checks" 3 
        New-ItemProperty -Path $RegLoc -Name ProvSSID -Value $NetworkInfo.Name -PropertyType String -Force -ErrorAction SilentlyContinue 
        New-ItemProperty -Path $RegLoc -Name ProvNetType -Value $NetworkInfo.InterfaceAlias -PropertyType String -Force -ErrorAction SilentlyContinue 
        New-ItemProperty -Path $RegLoc -Name ProvIPAddress -Value $NetIPAddress -PropertyType String -Force -ErrorAction SilentlyContinue 
    }

    $StartDate = (Get-ItemProperty -Path $RegLoc -Name ProvStartTime -ErrorAction SilentlyContinue).ProvStartTime

    if([int](New-TimeSpan -Start $StartDate -End $CurrentDate).TotalMinutes -gt 240)
    {
        Log-ScriptEvent $LogFile "System has been sat waiting for user - rewrite start time of device" "Autopilot_Checks" 2
        New-ItemProperty -Path $RegLoc -Name ProvStartTime -PropertyType String -Value $CurrentDate  -Force -ErrorAction SilentlyContinue   
         
    }
}
# End if status is new

# Load in the XML file for parsing
Log-ScriptEvent $LogFile "Loading $XMLFile" "Autopilot_Checks" 1 
[xml]$XmlDocument = Get-Content -Path $XMLFile

# Get all the items to be checked
$ItemsToCheck = $XmlDocument.AutopilotCheck.ItemCheck

# Get everything from Win32 Products and Installed Win32 programs - saves time this way
# Version 2.2.2.0 - changed to get-package
Log-ScriptEvent $LogFile "Retrieving Installed Products from Get Packagesget-" "Autopilot_Checks" 1 
$InstalledProducts = Get-Package

# Get the number of apps and application settings in the XML
$TotalAppCount = $ItemsToCheck.Count
Log-ScriptEvent $LogFile "Checking status of $TotalAppCount applications in XML file " "Autopilot_Checks" 1 
$TotalAllowedMinutes = $XmlDocument.AutopilotCheck.Settings.MaxTime
Log-ScriptEvent $LogFile "Total Allowed Minutes from XML file = $TotalAllowedMinutes" "Autopilot_Checks" 1 
$MaximumAppScore = $XmlDocument.AutopilotCheck.Settings.TotalScore
Log-ScriptEvent $LogFile "Maximum appscore from XML File = $MaximumAppScore" "Autopilot_Checks" 1 

# Added captrue of current AppScore from registry - version 1.3.0.0
$CurrentAppScore = (Get-ItemProperty -Path $RegLoc -Name ProvAppScore).ProvAppscore
$CurrentStatus = (Get-ItemProperty -Path $RegLoc -Name ProvStatus).ProvStatus

$StartDate = (Get-ItemProperty -Path $RegLoc -Name ProvStartTime -ErrorAction SilentlyContinue).ProvStartTime
Log-ScriptEvent $LogFile "Start time of Autopilot from Registry : $StartDate" "Autopilot_Checks" 1 
Log-ScriptEvent $LogFile "Current time of Autopilot : $CurrentDate" "Autopilot_Checks" 1 

if(($CurrentAppScore -ne $MaximumAppScore) -or ($CurrentStatus -ne "Completed"))
{

    # Check each of the items to be checked and run a case statement on each one
    foreach ($Item in $ItemsToCheck)
    {
        # Case statement checks the Type and runs the function accordingly, adding to the appscore as needed
        Switch ($Item.Type)
        {
           "InstalledProduct" {$TotalAppScore = $TotalAppScore + (Check-InstalledProduct -ApplicationName $Item.Check -AppScore $Item.Score -DisplayName $Item.DisplayName)}
           "InstalledLogFile" {$TotalAppScore = $TotalAppScore + (Check-InstalledLogFile -CheckFile $Item.File -StringtoMatch $Item.Check -AppScore $Item.Score -DisplayName $Item.DisplayName)}
           "InstalledStore" {$TotalAppScore = $TotalAppScore + (Check-WindowsStore -ApplicationName $Item.Check -AppScore $Item.Score -DisplayName $Item.DisplayName)}
        }
    }

    # Load the result in convert to binary and count apps installed
    $AppsToBinary = [Convert]::ToString($TotalAppScore,2)

    # Count the 1's in our string to get the amount of apps installed
    $CurrentAppCount = [regex]::matches($AppsToBinary,"1").count

    # Update log file with counts
    Log-ScriptEvent $LogFile "Current Appscore : $TotalAppScore" "Autopilot_Checks" 1 
    Log-ScriptEvent $LogFile "Current Number of Apps completed : $CurrentAppCount of $TotalAppCount" "Autopilot_Checks" 1 

    # Setup the Toast Notification
    $Button1 = New-BTButton -Dismiss -Content "Dismiss"
    $Header = New-BTHeader -Id Head1 -Title "Autopilot Provisioning"
    New-BTHeader -Title "Autopilot Provisioning" -Id 1

    # Check if everything has been completed
    If($CurrentAppCount -eq $TotalAppCount)
    {
        # Installation completed routine
        # Compare the times to get the total time in minutes
        $TotalTime = [int](New-TimeSpan -Start $StartDate -End $CurrentDate).TotalMinutes

        Log-ScriptEvent $LogFile "End time of Autopilot : $CurrentDate" "Autopilot_Checks" 1 
        Log-ScriptEvent $LogFile "Total minutes for Autopilot : $TotalTime" "Autopilot_Checks" 1 

        New-ItemProperty -Path $RegLoc -Name ProvEndTime -Value $CurrentDate -PropertyType String -Force -ErrorAction SilentlyContinue
        New-ItemProperty -Path $RegLoc -Name ProvTotalTime -Value $TotalTime -PropertyType String -Force -ErrorAction SilentlyContinue
        New-ItemProperty -Path $RegLoc -Name ProvStatus -Value "Completed" -PropertyType String -Force -ErrorAction SilentlyContinue
        New-ItemProperty -Path $RegLoc -Name ProvAppScore -Value $TotalAppScore -PropertyType String -Force -ErrorAction SilentlyContinue
        
        Log-ScriptEvent $LogFile "Autopilot timings written to registry" "Autopilot_Checks" 1 
        Log-ScriptEvent $LogFile "Removing schedule task to check Autopilot process" "Autopilot_Checks" 1 

        # Remove the scheduled task from the system to prevent rerunning of script
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        
        # Display notification
        New-BurntToastNotification -Text "Your provisioned system has completed Setup" -AppLogo "$DestSource\Autopilot_Hero.png" `
            -Button $button1 -Header $Header -UniqueIdentifier SAPAutoPilotCheck
        
        Log-ScriptEvent $LogFile "Autopilot Completed (0x0)" "Autopilot_Checks" 1 
        $NewStatus = "Complete"         
    }
    else
    {
        # Get a percentage for the log file
        [int]$PercentComplete = $CurrentAppCount / $TotalAppCount * 100

        # Now display it in the progress bar
        $ProgressBar = New-BTProgressBar -Status 'Running' -Value ($CurrentAppCount / $TotalAppCount)

        # Display notification only if the appscore has changed
        if($TotalAppScore -gt $CurrentAppScore)
        {
            New-BurntToastNotification -Text "Autopilot installation is still running" `
                -AppLogo "C:\$DestSoruce\Autopilot\Autopilot_Hero.png" -Header $Header -ProgressBar $ProgressBar -UniqueIdentifier SAPAutoPilotCheck
        }

        Log-ScriptEvent $LogFile "Autopilot still running - writing current status to registry" "Autopilot_Checks" 2 

        New-ItemProperty -Path $RegLoc -Name ProvStatus -Value "Installing" -PropertyType String -Force -ErrorAction SilentlyContinue
        New-ItemProperty -Path $RegLoc -Name ProvAppScore -Value $TotalAppScore -PropertyType String -Force -ErrorAction SilentlyContinue

        $NewStatus = "Installing"

    }

}
else
{
    Log-ScriptEvent $LogFile "Autopilot already completed - will rerun cleanup of Schedule Task" "Autopilot_Checks" 3
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
}

# Check that the installation hasn't taken too long
if(([int](New-TimeSpan -Start $StartDate -End $CurrentDate).TotalMinutes -gt [int]$TotalAllowedMinutes) -and ($NewStatus -eq "Installing"))
{
    Log-ScriptEvent $LogFile "Total time for Autopilot exceeded - Failed installation" "Autopilot_Checks" 3

    # Record the failure in the registry complete with the date of the failure
    New-ItemProperty -Path $RegLoc -Name ProvStatus -Value "Failed" -PropertyType String -Force -ErrorAction SilentlyContinue
    New-ItemProperty -Path $RegLoc -Name ProvEndTime -Value $CurrentDate -PropertyType String -Force -ErrorAction SilentlyContinue
    New-ItemProperty -Path $RegLoc -Name ProvTotalTime -Value $TotalAllowedMinutes -PropertyType String -Force -ErrorAction SilentlyContinue

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    
}