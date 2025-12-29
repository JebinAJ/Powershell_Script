
$ErrorActionPreference = 'Stop'
Import-Module ImportExcel

Connect-MgGraph -Scopes 'Application.Read.All','Directory.Read.All' | Out-Null

$timestamp   = Get-Date -Format 'yyyyMMdd_HHmm'
$exportPath  = Join-Path -Path (Get-Location) -ChildPath "AppRegistrations_Owners_$timestamp.xlsx"

Write-Host "Exporting to: $exportPath" -ForegroundColor Cyan

Write-Host "Fetching applications..." -ForegroundColor Yellow
$applications = Get-MgApplication -All

$withOwners    = New-Object System.Collections.Generic.List[object]
$withoutOwners = New-Object System.Collections.Generic.List[object]

$idx = 0
foreach ($app in $applications) {
    $idx++
    Write-Progress -Activity "Processing applications" -Status $app.DisplayName -PercentComplete (($idx / $applications.Count) * 100)

    $owners = Get-MgApplicationOwner -ApplicationId $app.Id -All

    if ($owners.Count -gt 0) {
        $ownerStrings = foreach ($o in $owners) {
            $p    = $o.AdditionalProperties
            $type = $p.'@odata.type'
            $dn   = $p.displayName
            $upn  = $p.userPrincipalName
            $spId = $p.appId

            switch ($type) {
                '#microsoft.graph.user'            { if ($dn -and $upn) { "$dn ($upn)" } elseif ($dn) { $dn } else { "User:$($o.Id)" } }
                '#microsoft.graph.servicePrincipal' { if ($dn -and $spId) { "$dn (SPN $spId)" } elseif ($dn) { "ServicePrincipal:$dn" } else { "ServicePrincipal:$($o.Id)" } }
                '#microsoft.graph.group'           { if ($dn) { "Group: $dn" } else { "Group:$($o.Id)" } }
                default                            { if ($dn) { $dn } else { $o.Id } }
            }
        }

        $withOwners.Add([pscustomobject]@{
            ApplicationName = $app.DisplayName
            AppId           = $app.AppId
            ObjectId        = $app.Id
            OwnerCount      = $owners.Count
            Owners          = ($ownerStrings -join '; ')
        })
    }
    else {
        $withoutOwners.Add([pscustomobject]@{
            ApplicationName = $app.DisplayName
            AppId           = $app.AppId
            ObjectId        = $app.Id
        })
    }
}

Write-Host "Writing Excel..." -ForegroundColor Yellow

$withOwners | Export-Excel -Path $exportPath `
    -WorksheetName 'WithOwners' `
    -TableName 'AppOwners' `
    -AutoSize -BoldTopRow -FreezeTopRow `
    -NumberFormat 'General'

$withoutOwners | Export-Excel -Path $exportPath `
    -WorksheetName 'WithoutOwners' `
    -TableName 'AppsNoOwners' `
    -AutoSize -BoldTopRow -FreezeTopRow `
    -Append -NumberFormat 'General'

Write-Host "Done. Excel saved at: $exportPath" -ForegroundColor Green
