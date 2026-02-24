# Intune App Deployment Status Checker

A PowerShell script that helps troubleshoot and monitor Intune app deployment status for managed devices.

## Overview

The **Intune App Deployment Status Checker** is a diagnostic tool designed for IT administrators to quickly verify:
- Whether a device is a member of a target AAD group
- Which required apps are assigned to that group
- The current deployment/installation status of those apps on the device

## Features

✅ **Device Resolution** - Find and verify Intune managed devices by name  
✅ **Group Membership Check** - Confirm device membership in target Azure AD groups  
✅ **App Assignment Detection** - Identify all required apps targeted to the group  
✅ **Deployment Status** - Real-time app installation status with visual indicators  
✅ **Device Details** - Display OS, sync time, and primary user information  
✅ **Complete App Inventory** - View all managed apps and their states on the device  

## Requirements

- **PowerShell 5.1** or higher
- **Microsoft Graph PowerShell SDK** installed
- **Permissions Required:**
  - `DeviceManagementApps.Read.All`
  - `DeviceManagementManagedDevices.Read.All`
  - `Group.Read.All`

### Installation

Install the Microsoft Graph PowerShell module:
```powershell
Install-Module Microsoft.Graph
```

## Usage

### 1. Configure Input Variables

Edit the script and update these values:
```powershell
$groupName  = "Group Name"        # AAD group name (e.g., "Marketing Team")
$deviceName = "Device Name"        # Intune device name (e.g., "LAPTOP-ABC123")
```

### 2. Run the Script

```powershell
.\Intune_App_Deployment_Status_Checker_Updated.ps1
```

The script will prompt you to authenticate via the Microsoft Graph using device code flow.

### 3. Alternative Authentication

For non-interactive scenarios, use an App Registration:
```powershell
# Connect using App Registration instead of interactive login
Connect-MgGraph -ClientId "your-client-id" `
               -TenantId "your-tenant-id" `
               -ClientSecret "your-client-secret"
```

## Script Workflow

The script executes the following steps:

### Step 1: Resolve AAD Group
- Searches for the specified Azure AD group by name
- Retrieves the group ID

### Step 2: Resolve Intune Device
- Finds the managed device by device name
- Collects device information (ID, OS, last sync time, primary user)

### Step 3: Check Group Membership
- Verifies device membership in the target AAD group
- Alerts if device is not a group member (won't receive targeted apps)

### Step 4: Find Required Apps
- Lists all apps assigned to the group with "required" intent
- Displays app names and IDs

### Step 5: Get Deployment Status
- Retrieves current installation status for each required app
- Shows detailed app information (version, install state)
- Displays complete inventory of all managed apps on device

## Output Indicators

| Symbol | Meaning |
|--------|---------|
| ✅ | Success / Installed |
| ❌ | Error / Failed |
| ⏳ | Pending / Not yet evaluated |
| ⚠️  | Warning / Not applicable |
| 📦 | App found |

## Troubleshooting

### "Device not found" Error
- Verify the exact device name in Intune (case-sensitive)
- Ensure the device is enrolled in Intune

### "Device not a member of group" Warning
- Add the device/user to the target AAD group
- Wait for group membership to sync (usually 15-30 minutes)

### App shows "Pending/Not yet evaluated"
The app assignment is new or awaiting sync. Solution:
```powershell
Sync-MgDeviceManagementManagedDevice -ManagedDeviceId "DeviceId"
```

Then re-run the script after a few minutes.

### Authentication Issues
- Ensure you have sufficient permissions in Microsoft Graph
- Use `Connect-MgGraph -UseDeviceCode` for interactive login
- For app-based auth, verify the app has required API permissions

## Version

**Version:** 1.0.1  
**Created by:** Kiran Kumar  
**Last Updated:** 20 Feb 26

## License

This script is provided as-is for IT administrative purposes.
