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
# This is a placeholder - customize based on your actual monitoring needs
$status = @{
    ComputerName = $computerName
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "Connection Status" = "Connected"
    "Version Number" = "1.0.0"
    "Policy Revision" = "Latest"
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
