# DEBUG VERSION - Enhanced logging
$RemoteServer = "https://13.59.39.162/api/status"
$ApiKey = "skyhighclientproxy"

Write-Host "=== Skyhigh Monitoring Script - DEBUG MODE ===" -ForegroundColor Cyan
Write-Host "Target Server: $RemoteServer" -ForegroundColor Yellow

# Skip SSL certificate validation for self-signed cert
if ($PSVersionTable.PSVersion.Major -ge 6) {
    # PowerShell 6+ (Core)
    $PSDefaultParameterValues['Invoke-WebRequest:SkipCertificateCheck'] = $true
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) (Core)" -ForegroundColor Green
} else {
    # Windows PowerShell 5.1
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) (Windows)" -ForegroundColor Green
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
Write-Host "Computer Name: $computerName" -ForegroundColor Green

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
    Write-Host "Version: $($status['Version Number'])" -ForegroundColor Green
} catch {
    $status["Version Number"] = "Unknown"
    Write-Host "Version: Unknown (registry key not found)" -ForegroundColor Yellow
}

# Get ALL properties from the About registry key
Write-Host "`nReading all data from registry key: $regPathAbout" -ForegroundColor Cyan
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
            Write-Host "  $name : U-$value" -ForegroundColor Green
        } else {
            $status[$name] = $value
            Write-Host "  $name : $value" -ForegroundColor Green
        }
    }
} catch {
    $status["Registry Status"] = "SCP Not Installed"
    Write-Host "Registry key not found - SCP may not be installed" -ForegroundColor Red
}

# Convert to JSON
$json = $status | ConvertTo-Json -Compress
Write-Host "`nJSON Payload:" -ForegroundColor Cyan
Write-Host $json -ForegroundColor White

# Send to monitoring server
Write-Host "`nSending request to server..." -ForegroundColor Cyan
try {
    $headers = @{
        "Authorization" = "Bearer $ApiKey"
        "Content-Type" = "application/json"
    }

    Write-Host "Headers:" -ForegroundColor Yellow
    $headers.GetEnumerator() | ForEach-Object {
        if ($_.Key -eq "Authorization") {
            Write-Host "  $($_.Key): Bearer ***" -ForegroundColor Gray
        } else {
            Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Gray
        }
    }

    $response = Invoke-WebRequest -Uri $RemoteServer -Method Post -Body $json -Headers $headers -UseBasicParsing -TimeoutSec 30

    Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
    Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Yellow
    Write-Host $response.Content -ForegroundColor White

} catch {
    Write-Host "`n=== ERROR ===" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Yellow
    Write-Host "Error Message: $($_.Exception.Message)" -ForegroundColor Red

    if ($_.Exception.Response) {
        Write-Host "`nHTTP Response Details:" -ForegroundColor Yellow
        Write-Host "  Status Code: $($_.Exception.Response.StatusCode.value__) $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        Write-Host "  Status Description: $($_.Exception.Response.StatusDescription)" -ForegroundColor Red

        try {
            $responseStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($responseStream)
            $responseBody = $reader.ReadToEnd()
            Write-Host "`nResponse Body:" -ForegroundColor Yellow
            Write-Host $responseBody -ForegroundColor White
            Write-Host "`nResponse Body Length: $($responseBody.Length) bytes" -ForegroundColor Gray
        } catch {
            Write-Host "  Could not read response body: $_" -ForegroundColor Gray
        }
    }

    if ($_.Exception.InnerException) {
        Write-Host "`nInner Exception:" -ForegroundColor Yellow
        Write-Host "  $($_.Exception.InnerException.Message)" -ForegroundColor Red
    }

    Write-Host "`nFull Error Record:" -ForegroundColor Yellow
    Write-Host ($_ | Format-List * -Force | Out-String) -ForegroundColor Gray

    exit 1
}
