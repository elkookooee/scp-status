# Windows Task Scheduler Setup

This guide shows how to configure Windows Task Scheduler to run the monitoring script every 5 minutes.

## Quick Setup Instructions

### 1. Open Task Scheduler
- Press `Win + R`
- Type `taskschd.msc`
- Press Enter

### 2. Create New Task
1. Click **"Create Task..."** (not "Create Basic Task")
2. **General Tab:**
   - Name: `Skyhigh Monitoring Status Report`
   - Description: `Reports Skyhigh Client Proxy status to monitoring dashboard every 5 minutes`
   - **Important:** Select "Run whether user is logged on or not"
   - Check "Run with highest privileges"
   - Configure for: Windows 10/Windows 11

### 3. Triggers Tab
1. Click **"New..."**
2. Begin the task: **On a schedule**
3. Settings: **Daily**
4. Start: (Set to current date/time)
5. Recur every: **1 days**
6. **Check:** Repeat task every: **5 minutes**
7. **For a duration of:** Indefinitely
8. **Check:** Enabled
9. Click OK

### 4. Actions Tab
1. Click **"New..."**
2. Action: **Start a program**
3. Program/script: `powershell.exe`
4. Add arguments:
   ```
   -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Path\To\monitor-final.ps1"
   ```
   **Replace `C:\Path\To\` with the actual path to your script!**
5. Click OK

### 5. Conditions Tab (Optional)
- **Uncheck:** "Start the task only if the computer is on AC power"
- **Uncheck:** "Stop if the computer switches to battery power"
- This ensures it runs on laptops even when unplugged

### 6. Settings Tab
- **Check:** Run task as soon as possible after a scheduled start is missed
- **Check:** If the running task does not end when requested, force it to stop
- **Uncheck:** Stop the task if it runs longer than (our script is fast)
- **If the task is already running:** Do not start a new instance

### 7. Save the Task
1. Click **OK**
2. Enter your Windows password when prompted
3. The task will now run every 5 minutes

## Verify It's Working

### Check Task History
1. In Task Scheduler, find your task
2. Click on the **History** tab (enable history if disabled)
3. Look for "Task completed" events every 5 minutes

### Check Dashboard
1. Open https://13.59.39.162
2. Your computer should appear within 5 minutes of creating the task
3. The "Last Updated" field should update every 5 minutes

## Configuration Details

**Script Interval:** 5 minutes
**Server Retention:** 7 minutes (2-minute safety buffer)
**Stale Indicator:** Clients appear faded after 2 minutes without update
**Auto-removal:** Clients removed after 7 minutes of inactivity

## Troubleshooting

### Task shows as "Running" but never completes
- Check if PowerShell execution policy is blocking the script
- Run this in PowerShell as Administrator:
  ```powershell
  Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
  ```

### Script works manually but not in Task Scheduler
- Make sure you used **absolute path** to the script in the action
- Example: `C:\Scripts\monitor-final.ps1` not just `monitor-final.ps1`
- Verify "Run whether user is logged on or not" is selected
- Check "Run with highest privileges" is enabled

### Data not appearing on dashboard
- Run the script manually first to test: `.\monitor-final.ps1`
- Check if Skyhigh proxy bypass is still configured for 13.59.39.162
- Verify the task is actually running (check History tab)

### Multiple computers on the dashboard
- Ensure each computer has a unique hostname
- The dashboard uses `$env:COMPUTERNAME` to identify clients

## Advanced: Run on Multiple Computers

To deploy to multiple computers:

1. **Using Group Policy:**
   - Copy `monitor-final.ps1` to a network share
   - Use GPO to create scheduled tasks on all computers
   - Path: Computer Configuration → Preferences → Control Panel Settings → Scheduled Tasks

2. **Using PowerShell Remoting:**
   ```powershell
   $computers = @("PC1", "PC2", "PC3")
   foreach ($computer in $computers) {
       # Copy script
       Copy-Item "monitor-final.ps1" "\\$computer\C$\Scripts\" -Force

       # Create scheduled task remotely
       Invoke-Command -ComputerName $computer -ScriptBlock {
           $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\monitor-final.ps1"'
           $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)
           $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
           Register-ScheduledTask -TaskName "Skyhigh Monitoring Status Report" -Action $action -Trigger $trigger -Principal $principal -Force
       }
   }
   ```

## Monitoring the Monitoring

To check which clients are reporting:
- Dashboard URL: https://13.59.39.162
- Search box filters by computer name
- Client count shown at top
- Auto-refreshes every 30 seconds

To see historical logs on the server:
```bash
ssh -i skyhigh-monitoring-key.pem ec2-user@13.59.39.162
sudo journalctl -u monitoring -f
```
