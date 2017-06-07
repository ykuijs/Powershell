# https://support.microsoft.com/en-us/help/952167

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
    $installedItems = $installedItems.DisplayName | Foreach-Object {
        if ($null -ne $_)
        {
            $_.Trim()
        }
    } | Sort-Object | Get-Unique
    
    [int]$installedVersion = 0
    switch ($installedItems)
    {
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

    $regKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $installedItems = Get-ItemProperty -Path $regKey | Where-Object -FilterScript { $_.DisplayName -match "^Microsoft SharePoint Server (2010|2013|2016)" }
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

    if ($version -lt 16)
    {
        Write-Log "$spServerInstallLocation\$version.0\Synchronization Service"
    }

    if ($version -eq 16)
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
        Write-Log "$($env:SystemDrive) \Users\$account\AppData\Local\Temp\WebTempDir"
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
        #Get the IIS Settings as defined in SharePoint, since this is a keyvaluepair object, we need to get the keys first
        $settings = $webApplication.IISSettings
        $keys = $settings.Keys
       
        #The keys correspond to the zones defined in SP
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
