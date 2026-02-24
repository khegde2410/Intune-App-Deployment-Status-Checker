#==============================================================
# Intune App Deployment Status Checker
# Known Values : Device Name, AAD Group Name
# Output       : App deployment status for Required apps
#                targeted to the group on the specified device
# Created by    : Kiran Kumar
# Version       : 1.0.1  20 Feb 26
#
#==============================================================

# ── Connect ───────────────────────────────────────────────────
Connect-MgGraph -Scopes @(
    "DeviceManagementApps.Read.All",
    "DeviceManagementManagedDevices.Read.All",
    "Group.Read.All"
) -UseDeviceCode

# Instead of Interactive login You can use App Registration with required Permissions 

#==============================================================
# INPUTS — Change these values
#==============================================================
$groupName  = "Group Name"
$deviceName = "Device Name"

#==============================================================
# STEP 1 — Resolve AAD Group
#==============================================================
Write-Host "`n=== Step 1: Resolving AAD Group ===" -ForegroundColor Cyan
$group = Get-MgGroup -Filter "displayName eq '$groupName'"

if (-not $group) {
    Write-Host "❌ Group '$groupName' not found. Exiting." -ForegroundColor Red
    return
}

$groupId = $group.Id
Write-Host "✅ Group : $($group.DisplayName) | ID: $groupId"

#==============================================================
# STEP 2 — Resolve Intune Managed Device
#==============================================================
Write-Host "`n=== Step 2: Resolving Intune Device ===" -ForegroundColor Cyan

$uri        = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$deviceName'"
$deviceResp = Invoke-MgGraphRequest -Method GET -Uri $uri

if ($deviceResp.value.Count -eq 0) {
    Write-Host "❌ Device '$deviceName' not found in Intune. Exiting." -ForegroundColor Red
    return
}

$intuneDevice    = $deviceResp.value[0]
$intuneDeviceId  = $intuneDevice.id
$azureAdDeviceId = $intuneDevice.azureADDeviceId
$userId          = $intuneDevice.userId

Write-Host "✅ Device Name      : $($intuneDevice.deviceName)"
Write-Host "   Intune Device ID : $intuneDeviceId"
Write-Host "   AAD Device ID    : $azureAdDeviceId"
Write-Host "   Primary User     : $($intuneDevice.userPrincipalName)"
Write-Host "   OS               : $($intuneDevice.operatingSystem) $($intuneDevice.osVersion)"
Write-Host "   Last Sync        : $($intuneDevice.lastSyncDateTime)"

#==============================================================
# STEP 3 — Check Device Membership in Group
#==============================================================
Write-Host "`n=== Step 3: Checking Group Membership ===" -ForegroundColor Cyan

$aadResp     = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$azureAdDeviceId'"
$aadObjectId = $aadResp.value[0].id
Write-Host "   AAD Object ID : $aadObjectId"

# Handle paginated group members
$memberUri   = "https://graph.microsoft.com/v1.0/groups/$groupId/members"
$allMembers  = @()

do {
    $memberResp  = Invoke-MgGraphRequest -Method GET -Uri $memberUri
    $allMembers += $memberResp.value
    $memberUri   = $memberResp.'@odata.nextLink'
} while ($memberUri)

$match = $allMembers | Where-Object { $_.id -eq $aadObjectId }

if ($match) {
    Write-Host "✅ Device IS a member of '$groupName'" -ForegroundColor Green
} else {
    Write-Host "❌ Device is NOT a member of '$groupName'" -ForegroundColor Red
    Write-Host "   The device will not receive apps targeted to this group." -ForegroundColor Yellow
}

#==============================================================
# STEP 4 — Find Required Apps Targeted to the Group
#==============================================================
Write-Host "`n=== Step 4: Finding Required Apps Targeted to Group ===" -ForegroundColor Cyan

$allApps      = Get-MgDeviceAppManagementMobileApp -All
$requiredApps = @()

foreach ($app in $allApps) {
    $assignments = Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $app.Id
    foreach ($a in $assignments) {
        if ($a.Target.AdditionalProperties.'groupId' -eq $groupId -and
            $a.Intent -eq "required") {
            $requiredApps += [PSCustomObject]@{
                AppName = $app.DisplayName
                AppId   = $app.Id
                Intent  = $a.Intent
            }
            Write-Host "   📦 $($app.DisplayName) | Intent: $($a.Intent)"
        }
    }
}

if ($requiredApps.Count -eq 0) {
    Write-Host "⚠️  No Required apps found assigned to this group." -ForegroundColor Yellow
    return
}

#==============================================================
# STEP 5 — Get Deployment Status via mobileAppIntentAndStates
#==============================================================
Write-Host "`n=== Step 5: App Deployment Status for '$deviceName' ===" -ForegroundColor Cyan

try {
    $uri     = "https://graph.microsoft.com/beta/users/$userId/mobileAppIntentAndStates/$intuneDeviceId"
    $resp    = Invoke-MgGraphRequest -Method GET -Uri $uri
    $appList = $resp.mobileAppList

    Write-Host "`n┌─────────────────────────────────────────────────────────────┐"
    Write-Host "│         REQUIRED APP DEPLOYMENT STATUS SUMMARY              │"
    Write-Host "└─────────────────────────────────────────────────────────────┘"

    foreach ($reqApp in $requiredApps) {
        $status = $appList | Where-Object { $_.applicationId -eq $reqApp.AppId }

        Write-Host ""
        if ($status) {
            $installState = $status.installState

            $color = switch ($installState) {
                "installed"          { "Green"  }
                "failed"             { "Red"    }
                "notInstalled"       { "Yellow" }
                "pendingInstall"     { "Yellow" }
                "notApplicable"      { "Gray"   }
                default              { "White"  }
            }

            $icon = switch ($installState) {
                "installed"      { "✅" }
                "failed"         { "❌" }
                "notInstalled"   { "⏳" }
                "pendingInstall" { "⏳" }
                "notApplicable"  { "⚠️" }
                default          { "❓" }
            }

            Write-Host "  $icon App          : $($status.displayName)" -ForegroundColor $color
            Write-Host "     App ID       : $($reqApp.AppId)"
            Write-Host "     Intent       : $($status.mobileAppIntent)"
            Write-Host "     Install State: $installState" -ForegroundColor $color
            Write-Host "     Version      : $($status.displayVersion)"

        } else {
            Write-Host "  ⏳ App          : $($reqApp.AppName)" -ForegroundColor Yellow
            Write-Host "     Install State: Pending / Not yet evaluated" -ForegroundColor Yellow
            Write-Host "     💡 Tip: Trigger a device sync and re-run this script."
        }
    }

    Write-Host ""
    Write-Host "┌─────────────────────────────────────────────────────────────┐"
    Write-Host "│                  ALL MANAGED APPS ON DEVICE                │"
    Write-Host "└─────────────────────────────────────────────────────────────┘"

    $appList | ForEach-Object {
        $icon = switch ($_.installState) {
            "installed"      { "✅" }
            "failed"         { "❌" }
            "notInstalled"   { "⏳" }
            "pendingInstall" { "⏳" }
            default          { "❓" }
        }
        $color = switch ($_.installState) {
            "installed" { "Green" }
            "failed"    { "Red"   }
            default     { "Yellow"}
        }
        Write-Host ("  {0,-3} {1,-45} {2,-20} {3}" -f $icon, $_.displayName, $_.mobileAppIntent, $_.installState) -ForegroundColor $color
    }
}
catch {
    Write-Host "❌ Error retrieving app status: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   💡 Trigger sync and retry:" -ForegroundColor Yellow
    Write-Host "      Sync-MgDeviceManagementManagedDevice -ManagedDeviceId '$intuneDeviceId'" -ForegroundColor White
}

Write-Host "`n=== ✅ Script Complete ===" -ForegroundColor Green