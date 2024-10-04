# Define the services, IIS sites, app pools, and health check URL
$services = @("ServiceName1", "ServiceName2")  # Replace with actual service names
$iisSites = @("Site1", "Site2")                # Replace with actual IIS site names
$appPools = @("AppPool1", "AppPool2")          # Replace with actual App Pool names
$healthCheckUrl = "http://yourdomain.com/healthcheck"  # Replace with actual health check URL

# Log file path
$logFilePath = "C:\Logs\ServiceMonitor.log"  # Change to your desired log file path

# Email settings
$smtpServer = "smtp.yourdomain.com"  # Replace with your SMTP server
$smtpFrom = "monitor@yourdomain.com"  # Replace with the sender email address
$smtpTo = "recipient1@domain.com,recipient2@domain.com"  # Replace with recipient emails (comma-separated)
$emailSubject = "Healthcheck Alert: Issue Detected"
$errorDetected = $false
$errorMessage = ""

# Function to log messages to a file
function Write-Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    Add-Content -Path $logFilePath -Value $logEntry
}

# Function to check and restart a service if it's not running
function Check-ServiceStatus {
    param (
        [string]$serviceName
    )
    $service = Get-Service -Name $serviceName
    if ($service.Status -ne 'Running') {
        $errorDetected = $true
        $errorMessage += "$serviceName is not running and could not be started.`n"
        Write-Host "$serviceName is not running. Attempting to start..."
        Write-Log "$serviceName is not running. Attempting to start..."
        Start-Service -Name $serviceName
        Start-Sleep -Seconds 5  # Wait a few seconds to check if it started successfully
        $service.Refresh()  # Refresh the service status
        if ($service.Status -eq 'Running') {
            Write-Host "$serviceName has started."
            Write-Log "$serviceName has successfully started."
        } else {
            Write-Host "Failed to start $serviceName."
            Write-Log "Failed to start $serviceName."
        }
    } else {
        Write-Host "$serviceName is running."
    }
}

# Function to check and restart an IIS site if it's stopped
function Check-IISSiteStatus {
    param (
        [string]$siteName
    )
    $site = Get-WebSite -Name $siteName
    if ($site.State -ne 'Started') {
        $errorDetected = $true
        $errorMessage += "$siteName is not running and could not be started.`n"
        Write-Host "$siteName is not running. Attempting to start..."
        Write-Log "$siteName is not running. Attempting to start..."
        Start-WebSite -Name $siteName
        Start-Sleep -Seconds 5  # Wait a few seconds to check if it started successfully
        $site = Get-WebSite -Name $siteName  # Refresh the site status
        if ($site.State -eq 'Started') {
            Write-Host "$siteName has started."
            Write-Log "$siteName has successfully started."
        } else {
            Write-Host "Failed to start $siteName."
            Write-Log "Failed to start $siteName."
        }
    } else {
        Write-Host "$siteName is running."
    }
}

# Function to check and restart an App Pool if it's stopped
function Check-AppPoolStatus {
    param (
        [string]$appPoolName
    )
    $appPool = Get-WebAppPoolState -Name $appPoolName
    if ($appPool.Value -ne 'Started') {
        $errorDetected = $true
        $errorMessage += "$appPoolName is not running and could not be started.`n"
        Write-Host "$appPoolName is not running. Attempting to start..."
        Write-Log "$appPoolName is not running. Attempting to start..."
        Start-WebAppPool -Name $appPoolName
        Start-Sleep -Seconds 5  # Wait a few seconds to check if it started successfully
        $appPool = Get-WebAppPoolState -Name $appPoolName  # Refresh the app pool status
        if ($appPool.Value -eq 'Started') {
            Write-Host "$appPoolName has started."
            Write-Log "$appPoolName has successfully started."
        } else {
            Write-Host "Failed to start $appPoolName."
            Write-Log "Failed to start $appPoolName."
        }
    } else {
        Write-Host "$appPoolName is running."
    }
}

# Function to check the health check URL
function Check-HealthCheckUrl {
    param (
        [string]$url
    )
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "Health check passed for $url"
        } else {
            $errorDetected = $true
            $errorMessage += "Health check failed for $url. Status Code: $($response.StatusCode).`n"
            Write-Host "Health check failed for $url. Status Code: $($response.StatusCode)"
            Write-Log "Health check failed for $url. Status Code: $($response.StatusCode)"
        }
    } catch {
        $errorDetected = $true
        $errorMessage += "Health check failed for $url. Error: $_.`n"
        Write-Host "Health check failed for $url. Error: $_"
        Write-Log "Health check failed for $url. Error: $_"
    }
}

# Function to send email if an error is detected
function Send-AlertEmail {
    param (
        [string]$subject,
        [string]$body
    )
    $mailMessage = New-Object system.net.mail.mailmessage
    $mailMessage.from = $smtpFrom
    $mailMessage.To.Add($smtpTo)
    $mailMessage.Subject = $subject
    $mailMessage.Body = $body
    $smtp = New-Object system.net.mail.smtpclient($smtpServer)
    try {
        $smtp.Send($mailMessage)
        Write-Host "Alert email sent successfully."
        Write-Log "Alert email sent to $smtpTo."
    } catch {
        Write-Host "Failed to send alert email: $_"
        Write-Log "Failed to send alert email: $_"
    }
}

# Create log directory if it doesn't exist
if (-not (Test-Path -Path (Split-Path $logFilePath))) {
    New-Item -ItemType Directory -Path (Split-Path $logFilePath) | Out-Null
}

# Monitor services
foreach ($service in $services) {
    Check-ServiceStatus -serviceName $service
}

# Monitor IIS Sites
foreach ($iisSite in $iisSites) {
    Check-IISSiteStatus -siteName $iisSite
}

# Monitor Application Pools
foreach ($appPool in $appPools) {
    Check-AppPoolStatus -appPoolName $appPool
}

# Check Healthcheck URL
Check-HealthCheckUrl -url $healthCheckUrl

# Send an email if any errors were detected
if ($errorDetected) {
    Send-AlertEmail -subject $emailSubject -body $errorMessage
}
