# Hardcoded configuration - hidden from end users
$RemoteServer = "https://13.59.39.162/api/status"
$ApiKey = "skyhighclientproxy"

# Skip SSL certificate validation for self-signed cert
if ($PSVersionTable.PSVersion.Major -ge 6) {
    # PowerShell 6+ (Core)
    $PSDefaultParameterValues['Invoke-WebRequest:SkipCertificateCheck'] = $true
} else {
    # Windows PowerShell 5.1
    if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
        add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    }
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}

# Get computer name
$computerName = $env:COMPUTERNAME

# Gather Skyhigh Client Proxy status
$status = @{
    ComputerName = $computerName
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Read registry keys for Skyhigh Client Proxy status
$regPathAbout = "HKLM:\SOFTWARE\Skyhigh\SCP\About"
$regPathGeneral = "HKLM:\SOFTWARE\Skyhigh\SCP\General"

# Get Version Number from General key
try {
    $version = Get-ItemProperty -Path $regPathGeneral -Name "Version" -ErrorAction Stop
    $status["Version Number"] = $version.Version
} catch {
    $status["Version Number"] = "Unknown"
}

# Get ALL properties from the About registry key
try {
    $aboutProps = Get-ItemProperty -Path $regPathAbout -ErrorAction Stop

    # PowerShell adds these metadata properties - filter them out
    $excludeProps = @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')

    # Add all registry values to status
    $aboutProps.PSObject.Properties | Where-Object { $excludeProps -notcontains $_.Name } | ForEach-Object {
        $name = $_.Name
        $value = $_.Value

        # Special handling for Policy Revision (DWORD) - format as U-###
        if ($name -eq "Policy Revision" -and $value -is [int]) {
            $status[$name] = "U-" + $value
        } else {
            $status[$name] = $value
        }
    }
} catch {
    # If registry key doesn't exist, add placeholder
    $status["Registry Status"] = "SCP Not Installed"
}

# Convert to JSON
$json = $status | ConvertTo-Json -Compress

# Send to monitoring server
try {
    $headers = @{
        "Authorization" = "Bearer $ApiKey"
        "Content-Type" = "application/json"
    }

    $response = Invoke-WebRequest -Uri $RemoteServer -Method Post -Body $json -Headers $headers -UseBasicParsing -TimeoutSec 30

    if ($response.StatusCode -eq 200) {
        Write-Host "Status successfully sent to monitoring server"
    } else {
        Write-Host "Unexpected response: $($response.StatusCode)"
    }
} catch {
    Write-Host "Failed to send status: $_"
    Write-Host "Error details: $($_.Exception.Message)"
    if ($_.Exception.InnerException) {
        Write-Host "Inner exception: $($_.Exception.InnerException.Message)"
    }
    exit 1
}
