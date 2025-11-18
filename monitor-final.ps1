# Hardcoded configuration - hidden from end users
$RemoteServer = "https://3.131.116.33/api/status"
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

# Get Version Number from registry
try {
    $version = Get-ItemProperty -Path $regPathGeneral -Name "Version" -ErrorAction Stop
    $status["Version Number"] = $version.Version
} catch {
    $status["Version Number"] = "Unknown"
}

# Get Connection Status from registry
try {
    $connectionStatus = Get-ItemProperty -Path $regPathAbout -Name "Connection Status" -ErrorAction Stop
    $status["Connection Status"] = $connectionStatus.'Connection Status'
} catch {
    $status["Connection Status"] = "Unknown"
}

# Get Policy Revision from registry (DWORD value)
try {
    $policyRev = Get-ItemProperty -Path $regPathAbout -Name "Policy Revision" -ErrorAction Stop
    $revisionNumber = $policyRev.'Policy Revision'
    $status["Policy Revision"] = "U-" + $revisionNumber
} catch {
    $status["Policy Revision"] = "Unknown"
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
