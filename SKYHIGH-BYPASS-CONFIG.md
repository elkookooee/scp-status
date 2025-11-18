# Skyhigh SSL Inspection Bypass Configuration

## Problem
The monitoring script is getting 403 Forbidden with "CertificateIncident" because Skyhigh Client Proxy is performing SSL inspection and blocking connections to the self-signed certificate on the monitoring server (13.59.39.162).

## Solution: Configure SSL Inspection Bypass

### Option 1: Local Client Configuration (If you have admin access)

1. **Check if you have local Skyhigh policy control:**
   - Open Skyhigh Client Proxy settings (usually in system tray)
   - Look for SSL/TLS or Certificate settings

2. **Add monitoring server to bypass list:**
   - Add IP: `13.59.39.162`
   - Or add hostname if using DNS

### Option 2: Central Policy Configuration (Requires Skyhigh Admin)

This requires access to the Skyhigh Web Gateway management console.

1. **Log into Skyhigh Web Gateway console**

2. **Navigate to SSL Inspection Bypass:**
   - Policy → Web Policy → SSL Scanner
   - Or: Configuration → SSL Configuration → Bypass List

3. **Add bypass rule:**
   ```
   Type: IP Address
   Value: 13.59.39.162
   Action: Do Not Decrypt
   ```

   **OR** (more specific):
   ```
   Type: URL
   Value: https://13.59.39.162/*
   Action: Do Not Decrypt
   ```

4. **Save and publish policy**

5. **Wait for policy to propagate** (usually 5-15 minutes)
   - Check current policy revision on client: The debug script shows "Policy Revision: U-466"
   - After update, this number should increment

### Option 3: Request IT/Security Team

If you don't have admin access to Skyhigh:

**Email template for IT/Security team:**

```
Subject: SSL Inspection Bypass Request for Internal Monitoring Server

Hi [IT/Security Team],

I need to configure an SSL inspection bypass for our internal Skyhigh Client
Proxy monitoring infrastructure.

Details:
- Server IP: 13.59.39.162
- Purpose: Internal monitoring dashboard for Skyhigh Client Proxy status
- Protocol: HTTPS (self-signed certificate)
- Security: Server is in AWS (us-east-2), restricted to authorized IPs only

Current issue: Skyhigh is blocking connections with "403 CertificateIncident"
because the monitoring server uses a self-signed certificate.

Request: Please add 13.59.39.162 to the SSL inspection bypass list so client
agents can report their status.

Thank you!
```

## Verify Configuration

After making changes, test with the debug script:
```powershell
.\monitor-debug.ps1
```

You should see:
```
=== SUCCESS ===
Status Code: 200
Response: {"status":"success"}
```

## Alternative: Check if bypass is already configured

Run this to see current Skyhigh logs:
```powershell
Get-Content "C:\ProgramData\Skyhigh\SCP\Logs\*" -Tail 50 | Select-String -Pattern "13.59.39.162|CertificateIncident"
```
