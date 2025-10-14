# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Skyhigh Client Proxy monitoring system that consists of:
- **AWS CloudFormation stack** that deploys a monitoring server on EC2
- **PowerShell client script** that sends client status updates to the monitoring server
- **Flask-based web dashboard** that displays real-time client status

## Architecture

### Monitoring Server (cloudformation.yaml)
The CloudFormation template deploys a complete monitoring infrastructure:
- **EC2 instance** running Amazon Linux 2 with Flask/Gunicorn backend
- **Flask API endpoint** at `/api/status` that accepts POST requests with Bearer token authentication
- **Web dashboard** at `/` that displays client statuses in a grid layout with auto-refresh
- **Nginx reverse proxy** handling HTTPS with self-signed certificates
- **Security group** allowing inbound traffic on ports 443 (HTTPS) and 22 (SSH)
- **Elastic IP** for persistent addressing
- **IAM role** with CloudWatch and SSM permissions

The Flask app (embedded in UserData) maintains an in-memory dictionary (`client_statuses`) of client statuses, keyed by computer name. Each status update includes:
- ComputerName
- Timestamp
- Connection Status
- Version Number
- Policy Revision
- LastUpdated (server-side timestamp)

### Client Script (monitor-final.ps1)
PowerShell script that runs on Windows clients to report status to the monitoring server:
- Accepts `RemoteServer` (API URL) and `ApiKey` parameters
- Handles SSL certificate validation bypass for self-signed certificates (supports both PowerShell 5.1 and 6+)
- Gathers system status (currently placeholder data - customize for actual Skyhigh Client Proxy monitoring)
- Sends JSON payload via POST to `/api/status` with Bearer token authentication

## Deployment

### Deploy the monitoring server:
```bash
aws cloudformation create-stack \
  --stack-name skyhigh-monitoring \
  --template-body file://cloudformation.yaml \
  --parameters ParameterKey=KeyName,ParameterValue=<your-key-name> \
               ParameterKey=ApiKey,ParameterValue=<your-api-key> \
  --capabilities CAPABILITY_IAM
```

### Get the server URL after deployment:
```bash
aws cloudformation describe-stacks \
  --stack-name skyhigh-monitoring \
  --query 'Stacks[0].Outputs'
```

### Run the client monitoring script:
```powershell
.\monitor-final.ps1 -RemoteServer "https://<server-ip>/api/status" -ApiKey "your-api-key"
```

### Test the API endpoint:
```powershell
.\test-api.ps1
```
Note: Update the hardcoded IP address in test-api.ps1 with your actual server IP.

## CloudFormation Stack Parameters

- **InstanceType**: EC2 instance size (default: t3.micro)
- **ApiKey**: Bearer token for API authentication (default: skyhighclientproxy)
- **AllowedCIDR**: IP range allowed to access the server (default: 0.0.0.0/0)
- **KeyName**: EC2 key pair name for SSH access

## Important Files

- **cloudformation.yaml**: Complete infrastructure-as-code definition
- **monitor-final.ps1**: Production client monitoring script
- **test-api.ps1**: Test script for validating API endpoint
- **skyhigh-monitoring-key.pem**: EC2 SSH private key (sensitive)

## Security Notes

- The monitoring server uses self-signed SSL certificates generated during deployment
- API authentication uses Bearer token passed via Authorization header
- Client scripts disable certificate validation to work with self-signed certs
- The API key is embedded in the UserData script and should match the client script parameter
