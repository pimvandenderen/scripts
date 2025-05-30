<#
README

Azure Activity Log Alert Summary Script
---------------------------------------

This PowerShell script connects to your Azure account, iterates through all your subscriptions, and summarizes the presence of Azure Activity Log Alerts related to Service Health. It checks for alerts about Service Issues, Planned Maintenance, Health Advisories, and Security Advisories in each subscription.

**What it does:**
- Ensures required Az PowerShell modules are installed.
- Connects to Azure interactively.
- For each subscription:
  - Switches context.
  - Retrieves all Activity Log Alerts.
  - Checks for Service Health alert types (Incident, Maintenance, Informational, ActionRequired, Security).
  - Summarizes which alert types are present.
- Outputs a table summarizing the findings per subscription.

**How to use:**
1. Open PowerShell and ensure you have permission to install modules and access Azure subscriptions.
2. Save this script to a `.ps1` file.
3. Run the script in PowerShell:
   `.\YourScriptName.ps1`
4. Sign in when prompted.
5. Review the output table for a summary of Service Health alert coverage across your subscriptions.

**Exporting to CSV:**
- To export the results to a CSV file, use the `-ExportCsv` parameter and specify the desired output path:
  `.\YourScriptName.ps1 -ExportCsv "C:\Path\To\Output.csv"`

**Required Azure Permissions:**
- You must have the **Reader** role (or higher, e.g., Contributor or Owner) on each subscription you want to query.
- The script requires permission to:
  - Sign in interactively (Azure AD account)
  - Read Activity Log Alerts (`Microsoft.Insights/activityLogAlerts/read`)
  - List subscriptions (`Microsoft.Resources/subscriptions/read`)
- No write or admin permissions are required in Azure for running the script itself.
- Local administrator rights may be needed to install PowerShell modules if not already present.

**Example CSV Output:**
"SubscriptionId","SubscriptionName","ServiceIssues","PlannedMaintenance","HealthAdvisories","SecurityAdvisories"
"11111111-aaaa-bbbb-cccc-222222222222","Contoso Production",True,True,True,True
"33333333-dddd-eeee-ffff-444444444444","Contoso Dev",True,False,True,False
"55555555-gggg-hhhh-iiii-666666666666","Contoso Test",False,False,False,False

Note: You may need to run PowerShell as Administrator to install modules if they are not already present.

#>

# Parameters
param (
    [parameter(Mandatory = $false)]
    [string] $ExportCsv
)

# Ensure required modules are available
$requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.Monitor')

# Check if required modules are installed, if not, install them
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module"
        Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
    }
}

# Import modules
Import-Module Az.Accounts
Import-Module Az.Resources
Import-Module Az.Monitor



# Connect to Azure
try {
    # Check if user is already authenticated
    $context = Get-AzContext
    if (-not $context.Account) {
        # Not authenticated, prompt for login
        Connect-AzAccount -ErrorAction Stop
    } else {
        Write-Host "Already authenticated as $($context.Account.Id)"
    }
} catch {
    Write-Error "Failed to connect to Azure: $_"
    exit 1
}

# Retrieve all subscriptions
try {
    # Get all subscriptions
    $subscriptions = Get-AzSubscription -ErrorAction Stop
} catch {
    Write-Error "Failed to retrieve Azure subscriptions: $_"
    exit 1
}

# Prepare results array
$results = @()

foreach ($sub in $subscriptions) {
    try {
        Set-AzContext -SubscriptionId $sub.Id -ErrorAction Stop | Out-Null

        # Get all activity log alerts
        $alerts = Get-AzActivityLogAlert -ErrorAction Stop
    } catch {
        Write-Warning "Failed to process subscription $($sub.Name) ($($sub.Id)): $_"
        continue
    }

    # Initialize flags ONCE per subscription
    $serviceIssues = $false
    $plannedMaintenance = $false
    $healthAdvisories = $false
    $securityAdvisories = $false

    foreach ($alert in $alerts) {
        $allOf = $alert.ConditionAllOf

        # Only check ServiceHealth alerts
        if ($allOf -and $allOf[0].Field -eq 'category' -and $allOf[0].Equal -eq 'ServiceHealth') {
            $allTypes = $false

            # Defensive: If $allOf[1] is missing or empty, treat as "All"
            if (
                $allOf.Count -le 1 -or -not $allOf[1] -or
                (
                    -not $allOf[1].AnyOf -and
                    -not $allOf[1].Equal -and
                    -not $allOf[1].Equals
                )
            ) {
                $allTypes = $true
            }
            # Or, if $allOf[1].Equal(s) is 'All'
            elseif (
                ($allOf[1].Equal -eq 'All') -or
                ($allOf[1].Equals -eq 'All')
            ) {
                $allTypes = $true
            }

            if ($allTypes) {
                $serviceIssues = $true
                $plannedMaintenance = $true
                $healthAdvisories = $true
                $securityAdvisories = $true
            } elseif ($allOf[1].AnyOf) {
                foreach ($type in $allOf[1].AnyOf) {
                    switch ($type.Equal) {
                        'Incident'         { $serviceIssues = $true }
                        'Maintenance'      { $plannedMaintenance = $true }
                        'Informational'    { $healthAdvisories = $true }
                        'ActionRequired'   { $healthAdvisories = $true }
                        'Security'         { $securityAdvisories = $true }
                    }
                }
            }
        }
    }

    # Add result
    $results += [PSCustomObject]@{
        SubscriptionId       = $sub.Id
        SubscriptionName     = $sub.Name
        ServiceIssues        = $serviceIssues
        PlannedMaintenance   = $plannedMaintenance
        HealthAdvisories     = $healthAdvisories
        SecurityAdvisories   = $securityAdvisories
    }
}



if ($ExportCsv) {
    $results | Export-Csv -Path $ExportCsv -NoTypeInformation -Force
    Write-Host "Results exported to $exportCsv"
}

# Output results
$results | Format-Table -AutoSize
