<#  
.SYNOPSIS
    Generating an overview of required file system antivirus exclusions
.DESCRIPTION
    The SharePoint Product Group has published all required file system antivirus exclusions for SharePoint.
    This list can be found at:
    https://support.office.com/en-us/article/certain-folders-may-have-to-be-excluded-from-antivirus-scanning-when-you-use-file-level-antivirus-software-in-sharepoint-01cbc532-a24e-4bba-8d67-0b1ed733a3d9

    This script generates an overview of all file locations which need to be excluded, based on the previous
    KB article.
.PARAMETER
    The script does not have any input parameters.
.EXAMPLE
    .\SP_AV_Exclusions.ps1
    Run the script
.NOTES  
    File Name     : SP_AV_Exclusions.ps1
    Author        : Yorick Kuijs
    Version       : 1.0.4
	Last Modified : 21-03-2019
.CHANGES
    v1.0.0 - Initial release (01-06-2017)
    v1.0.1 - Included feedback comments (16-06-2017)
    v1.0.2 - Included dynamic logging and search folders (12-07-2017)
    v1.0.3 - Updated the SP2010 version check and SP2010 search folder generation (30-08-2018)
    v1.0.4 - Added SharePoint 2019 support (21-03-2019)
.LINK
	https://github.com/ykuijs/Powershell/tree/dev/SharePoint
#>

function Write-Log()
{
    param (
        [Parameter(Mandatory=$true)]
        [System.String]
        $Message
    )
    Write-Output "  $Message"
}

# ======================================================================================
# Gets the account used by the OSearch Service
# ======================================================================================
function Get-SearchServiceAccount()
{
    $service = Get-WmiObject -Query "select * from win32_service where name LIKE 'OSearch%'"
    if ($service -is [System.Management.ManagementObject])
    {
        return $service.startname
    }
    else
    {
        return $null
    }
}

# ======================================================================================
# Gets the accounts used by SharePoint
# ======================================================================================
function Get-Accounts()
{
    $accounts = New-Object System.Collections.Generic.List``1[System.String]
    
    $managedaccounts = Get-SPManagedAccount
    foreach ($ma in $managedaccounts)
    {
        if ($accounts.Contains($ma.UserName))
        {   
            continue
        }
        $accounts.Add($ma.UserName)
    }

    $webapps = Get-SPWebApplication -IncludeCentralAdministration
    foreach ($webapp in $webapps)
    {
        $username = $webapp.ApplicationPool.Username
        if ($accounts.Contains($username))
        {   
            continue
        }
        $accounts.Add($username)       
    }

    return $accounts | Sort-Object
}

# ======================================================================================
# Ensures the SharePoint PowerShell snapins are loaded
# ======================================================================================
function EnsureSharePointPowershellSnapinLoaded ()
{
    if (-Not(Get-PSSnapin | ? { $_.Name -eq "Microsoft.SharePoint.PowerShell" })) {
        Add-PSSnapin Microsoft.SharePoint.PowerShell
    }
}

# ======================================================================================
# Determines version of SharePoint is being used
# ======================================================================================
function DetermineSharePointVersion()
{
    $x86Path = "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $installedItemsX86 = Get-ItemProperty -Path $x86Path | Select-Object -Property DisplayName
    
    $x64Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $installedItemsX64 = Get-ItemProperty -Path $x64Path | Select-Object -Property DisplayName

    $installedItems = $installedItemsX86 + $installedItemsX64
    $installedItems = $installedItems | Sort-Object -Property DisplayName -Unique | Where-Object { $null -ne $_.DisplayName } | ForEach-Object {$_.DisplayName.Trim() }
<#    $installedItems = $installedItems | Select-Object -Property DisplayName | Foreach-Object {
        if ($null -ne $_)
        {
            $_.Trim()
        }
    } | Sort-Object | Get-Unique#>
    
    [int]$installedVersion = 0
    switch ($installedItems)
    {
        "Microsoft SharePoint Server 2019"
        {
            Write-Host "Using SharePoint Server 2019" -ForegroundColor Yellow
            $installedVersion = 16;
            break
        }
        "Microsoft SharePoint Server 2016" 
        {
            Write-Host "Using SharePoint Server 2016" -ForegroundColor Yellow  
            $installedVersion = 16;
            break
        }
        "Microsoft SharePoint Server 2013"
        {
            Write-Host "Using SharePoint Server 2013" -ForegroundColor Yellow  
            $installedVersion = 15;
            break
        }
        "Microsoft SharePoint Server 2010"
        {
            Write-Host "Using SharePoint Server 2010" -ForegroundColor Yellow  
            $installedVersion = 14;
            break
        }
        default{}
    }
       
    return [int32]$installedVersion
}

# ======================================================================================
# .NET 4.0 folders
# ======================================================================================
function Net40Paths
{
    Write-Host "ASP.NET folders" -ForegroundColor Green
    Write-Log "$($env:SystemDrive)\Windows\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files"
    Write-Log "$($env:SystemDrive)\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"
}

function Net20Paths
{
    Write-Host "ASP.NET folders" -ForegroundColor Green
    Write-Log "$($env:SystemDrive)\Windows\Microsoft.NET\Framework64\v2.0.50727\Temporary ASP.NET Files"
    Write-Log "$($env:SystemDrive)\Windows\Microsoft.NET\Framework64\v2.0.50727\Config"
}

# ======================================================================================
# Windows log folders
# ======================================================================================
function WindowsLogFolders
{
    Write-Host "Windows Log folders" -ForegroundColor Green
    Write-Log "$($env:SystemDrive)\WINDOWS\System32\LogFiles"
    Write-Log "$($env:SystemDrive)\Windows\Syswow64\LogFiles"
}

# ======================================================================================
# SharePoint generic folders
# ======================================================================================
function SharePointFolders([int]$version)
{
    Write-Host "SharePoint generic folder" -ForegroundColor Green
    Write-Log "$($env:SystemDrive)\ProgramData\Microsoft\SharePoint"

    Write-Host "SharePoint Foundation folder" -ForegroundColor Green
    Write-Log "$($env:SystemDrive)\Program Files\Common Files\Microsoft Shared\Web Server Extensions"

    Write-Host "or just these subfolders" -ForegroundColor Green
    Write-Log "$($env:SystemDrive)\Program Files\Common Files\Microsoft Shared\Web Server Extensions\$version"
    Write-Log "$($env:SystemDrive)\Program Files\Common Files\Microsoft Shared\Web Server Extensions\$version\Logs"

    if ($version -lt 16)
    {
        Write-Log "$($env:SystemDrive)\Program Files\Common Files\Microsoft Shared\Web Server Extensions\$version\Data\Applications"
    }

    $loglocation = (Get-SPDiagnosticConfig).LogLocation.TrimEnd("\")
    if ($loglocation -match "(%\w*%)\w*")
    {
        $replace = [System.Environment]::ExpandEnvironmentVariables($matches[1])
        $loglocation = $loglocation -replace $matches[1], $replace
    }
    if ($loglocation -ne "$($env:SystemDrive)\Program Files\Common Files\Microsoft Shared\Web Server Extensions\$version\Logs")
    {
        Write-Log "$loglocation"
    }

    $regKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $installedItems = Get-ItemProperty -Path $regKey | Where-Object -FilterScript { $_.DisplayName -match "^Microsoft SharePoint Server (2010|2013|2016|2019)" }
    if ($null -eq $installedItems)
    {
        Write-Error "Cannot find any installed SharePoint products"
    }
    else
    {
        $spServerInstallLocation = $installedItems[0].InstallLocation
    }

    Write-Host "SharePoint Server folder" -ForegroundColor Green
    Write-Log "$spServerInstallLocation"

    Write-Host "or just these subfolders" -ForegroundColor Green
    Write-Log "$spServerInstallLocation\$version.0\Bin"
    Write-Log "$spServerInstallLocation\$version.0\Data"
    Write-Log "$spServerInstallLocation\$version.0\Logs"

    $ssi = Get-SPEnterpriseSearchServiceInstance
    if ($null -ne $ssi -and $ssi.Components.Count -ge 1)
    {
        Write-Log "$($ssi.Components[0].IndexLocation)"
    }

    if ($version -gt 14)
    {
        $ssas = Get-SPEnterpriseSearchServiceApplication
        foreach ($ssa in $ssas)
        {
            $topo = Get-SPEnterpriseSearchTopology -SearchApplication $ssa -Active
            $components = Get-SPEnterpriseSearchComponent -SearchTopology $topo
            foreach ($component in $components)
            {
                if ($null -ne $component.RootDirectory -and $component.RootDirectory -ne "")
                {
                    Write-Log "$($component.RootDirectory)"
                }
            }
        }
    }


    if ($version -lt 16)
    {
        Write-Log "$spServerInstallLocation\$version.0\Synchronization Service"
    }

    if ($version -ge 16)
    {
        Write-Host "SharePoint Server folder" -ForegroundColor Green
        Write-Log "$spServerInstallLocation\$version.0\Data\Office Server\Applications"
    }
}

# ======================================================================================
# Checking Search account folders
# ======================================================================================
function CheckSearchAccount()
{
    $searchaccount = Get-SearchServiceAccount
    if ($null -eq $searchaccount)
    {
        Write-Verbose "No Search found"
    }
    else
    {
        $tempaccount = $searchaccount -split "\\"
        $account = $tempaccount[1]
        Write-Log "$($env:SystemDrive)\Users\$account\AppData\Local\Temp\WebTempDir"
        Write-Log "$($env:SystemDrive)\Users\$account\AppData\Local\Temp"
    }
}

# ======================================================================================
# Checking all other accounts used by SharePoint
# ======================================================================================
function CheckAllOtherAccounts()
{
    Write-Host "SharePoint service accounts Profile Temp folders" -ForegroundColor Green
    $managedaccounts = Get-Accounts
    foreach ($ma in $managedaccounts)
    {
        Write-Log "$($env:SystemDrive)\Users\$ma\AppData\Local\Temp"
    }
    Write-Log "$($env:SystemDrive)\Users\Default\AppData\Local\Temp"
}


# ======================================================================================
# Checking IIS folders used by SharePoint WebApplications
# ======================================================================================
function WebApplicationIIS()
{
    Write-Host "IIS SharePoint web app folders" -ForegroundColor Green
    Write-Log "$($env:SystemDrive)\inetpub\wwwroot\wss\VirtualDirectories"
       
    $webApplications = Get-SPWebApplication -IncludeCentralAdministration
       
    foreach($webApplication in $webApplications)
    {
        # Get the IIS Settings as defined in SharePoint, since this is a keyvaluepair object,
        # we need to get the keys first
        $settings = $webApplication.IISSettings
        $keys = $settings.Keys
       
        # The keys correspond to the zones defined in SP
        foreach($key in $keys)
        {            
            $setting = $settings[$key]
            Write-Log $setting.Path

            if ($version -lt 16)
            {
                $webconfiglocation = Join-Path -Path $setting.Path -ChildPath "web.config" -Resolve
                [xml]$webconfig = Get-Content $webconfiglocation
                if ($webconfig.configuration.SharePoint.BlobCache.enabled -eq "true")
                {
                    $blobcache = $webconfig.configuration.SharePoint.BlobCache.Location
                }
            }
        }
    }
       
    Write-Log "$($env:SystemDrive)\inetpub\temp\IIS Temporary Compressed Files"

    Write-Host "Blobcache locations" -ForegroundColor Green
    $blobcache | Sort-Object | Get-Unique | ForEach-Object -Process { Write-Log $_ }
}

# ======================================================================================
# Checking all running SharePoint processes
# ======================================================================================
function CheckRunningProcesses()
{
    $processes = ("w3wp", "owstimer", "wssadmin", "wsstracing", "mssearch", "noderunner", "ParserServer", "hostcontrollerservice", "mssdmn")

    Write-Host "Running SharePoint processes:" -ForegroundColor Green
    foreach ($process in $processes)
    {
        $proc = Get-Process $process -EA 0
        if ($null -ne $proc)
        {
            Write-Log "$process"
        }
    }
}



# Load the SharePoint PowerShell snapin
EnsureSharePointPowershellSnapinLoaded

# Determine the SharePoint version which is installed
$version = DetermineSharePointVersion

# Check the SharePoint Folders
SharePointFolders $version

# Check the default Windows Folders 
WindowsLogFolders

# Check the ASP.NET folders
if ($version -gt 14)
{Net40Paths}
else
{Net20Paths}

# Check the folder used by the search account
CheckSearchAccount

# Check the userprofile folders of all the other accounts
CheckAllOtherAccounts

# Check the folders used by the SharePoint WebApplications
WebApplicationIIS

# Check known SharePoint processes
CheckRunningProcesses