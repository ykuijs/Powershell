<#  
.SYNOPSIS  
    Determine what are the highest and lowest build numbers installed on the current SharePoint server
.DESCRIPTION  
    This script determines what are highest and lowest build numbers installed on the current SharePoint
    server. It is based on the "Product and patch installation status" page in Central Administration,
    which is THE source to check the current patch level.
.PARAMETER
    The script does not have any input parameters.
.EXAMPLE
    .\SP_VerionCheck.ps1
    Run the script
.NOTES  
    File Name     : SP_VerionCheck.ps1
    Author        : Yorick Kuijs
    Version       : 1.0.0
	Last Modified : 01-06-2017
.CHANGES
    v1.0.0 - Initial release
.LINK
	https://github.com/ykuijs/Powershell/tree/dev/SharePoint
#>

if ($null -eq (Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue))
{
    Add-PSSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue
}

$farm = Get-SPFarm
$productVersions = [Microsoft.SharePoint.Administration.SPProductVersions]::GetProductVersions($farm)
$server = Get-SPServer -Identity $env:COMPUTERNAME
$versionInfo = @{}
$versionInfo.Highest = ""
$versionInfo.Lowest = ""

$serverProductInfo = $productVersions.GetServerProductInfo($server.id)
$products = $serverProductInfo.Products

if ($ProductToCheck)
{
    $products = $products | Where-Object -FilterScript { 
        $_ -eq $ProductToCheck 
    }
        
    if ($null -eq $products)
    {
        throw "Product not found: $ProductToCheck"
    }
}

# Loop through all products
foreach ($product in $products)
{
    $singleProductInfo = $serverProductInfo.GetSingleProductInfo($product)
    $patchableUnits = $singleProductInfo.PatchableUnitDisplayNames

    # Loop through all individual components within the product
    foreach ($patchableUnit in $patchableUnits)
    {
        # Check if the displayname is the Proofing tools (always mentioned in first product,
        # generates noise)
        if (($patchableUnit -notmatch "Microsoft Server Proof") -and
            ($patchableUnit -notmatch "SQL Express") -and
            ($patchableUnit -notmatch "OMUI") -and
            ($patchableUnit -notmatch "XMUI") -and
            ($patchableUnit -notmatch "Project Server") -and
            ($patchableUnit -notmatch "Microsoft SharePoint Server (2013|2016)"))
        {
            $patchableUnitsInfo = $singleProductInfo.GetPatchableUnitInfoByDisplayName($patchableUnit)
            $currentVersion = ""
            foreach ($patchableUnitInfo in $patchableUnitsInfo)
            {
                # Loop through version of the patchableUnit
                $currentVersion = $patchableUnitInfo.LatestPatch.Version.ToString()

                # Check if the version of the patchableUnit is the highest for the installed product
                if ($currentVersion -gt $versionInfo.Highest)
                {
                    $versionInfo.Highest = $currentVersion
                }

                if ($versionInfo.Lowest -eq "")
                {
                    $versionInfo.Lowest = $currentVersion
                }
                else
                {
                    if ($currentversion -lt $versionInfo.Lowest)
                    {
                        $versionInfo.Lowest = $currentVersion
                    }
                }
            }
        }
    }
}
return $versionInfo
