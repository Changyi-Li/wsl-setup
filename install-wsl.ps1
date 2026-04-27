# install-wsl.ps1
# This script prompts for a WSL instance name and username, creates a dedicated directory on D:,
# imports the WSL distribution, and configures the default user.

do {
    $InstanceName = Read-Host "Enter the name for the new WSL instance"
    if ([string]::IsNullOrWhiteSpace($InstanceName)) {
        Write-Host "Error: Instance name is mandatory." -ForegroundColor Yellow
    }
} while ([string]::IsNullOrWhiteSpace($InstanceName))

$BaseDir = "D:\WSL"
$InstallDir = Join-Path $BaseDir $InstanceName
$SourcePath = Join-Path $BaseDir "source\install.tar.gz"

if (Test-Path $InstallDir) {
    Write-Host "Error: Directory '$InstallDir' already exists." -ForegroundColor Red
    exit 1
}

$UserName = Read-Host "Enter the username for this instance [default: changyi_li]"
if ([string]::IsNullOrWhiteSpace($UserName)) {
    $UserName = "changyi_li"
}

do {
    $Password = Read-Host "Enter the password for $UserName"
    if ([string]::IsNullOrWhiteSpace($Password)) {
        Write-Host "Error: Password is mandatory." -ForegroundColor Yellow
    }
} while ([string]::IsNullOrWhiteSpace($Password))

# Create the installation directory
Write-Host "Creating directory: $InstallDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

# Import the WSL instance
Write-Host "Importing WSL instance '$InstanceName'..." -ForegroundColor Cyan
wsl --import $InstanceName $InstallDir $SourcePath

if ($LASTEXITCODE -eq 0) {
    Write-Host "Success: WSL instance '$InstanceName' imported." -ForegroundColor Green
    
    Write-Host "Configuring user '$UserName'..." -ForegroundColor Cyan
    
    # Create the user using adduser (wrapped in bash -c to avoid PowerShell argument parsing issues)
    wsl -d $InstanceName -- bash -c "adduser --disabled-password --gecos '' $UserName && usermod -aG sudo $UserName"

    # Set the user password
    Write-Host "Setting password for $UserName..." -ForegroundColor Cyan
    # Escape single quotes in username and password for the printf command
    $EscapedUser = $UserName -replace "'", "'\''"
    $EscapedPass = $Password -replace "'", "'\''"
    $PasswordCommand = "printf '%s:%s\n' '$EscapedUser' '$EscapedPass' | chpasswd"
    wsl -d $InstanceName -- bash -c "$PasswordCommand"

    # Set default user and disable Windows path integration via /etc/wsl.conf
    Write-Host "Configuring /etc/wsl.conf (Default User: $UserName, Interop: Disabled)..." -ForegroundColor Cyan
    $WslConfContent = "[user]\ndefault=$UserName\n\n[interop]\nappendWindowsPath = false\n"
    $WslConfCommand = "printf '$WslConfContent' > /etc/wsl.conf"
    wsl -d $InstanceName -- bash -c "$WslConfCommand"

    # Set no_proxy in ~/.bashrc for the user
    Write-Host "Setting no_proxy in ~/.bashrc..." -ForegroundColor Cyan
    $NoProxyContent = '\n# Proxy settings for local connections\nexport no_proxy="localhost,127.0.0.1,::1"'
    $NoProxyCommand = "printf '$NoProxyContent\n' >> /home/$UserName/.bashrc"
    wsl -d $InstanceName -- bash -c "$NoProxyCommand"

    # Terminate the instance to ensure wsl.conf is read on next start
    Write-Host "Restarting instance to apply changes..." -ForegroundColor Cyan
    wsl --terminate $InstanceName
    
    $RunSetup = Read-Host "Do you want to clone the wsl-setup repository and run the Linux setup script now? (Y/n)"
    if ([string]::IsNullOrWhiteSpace($RunSetup) -or $RunSetup.ToLower() -eq 'y') {
        Write-Host "Ensuring git is installed (running as root)..." -ForegroundColor Cyan
        wsl -d $InstanceName -u root -- bash -c "apt-get update && apt-get install -y git"
        
        Write-Host "Cloning repository and running setup script..." -ForegroundColor Cyan
        $SetupCmd = "mkdir -p ~/src && git clone https://github.com/Changyi-Li/wsl-setup.git ~/src/wsl-setup && cd ~/src/wsl-setup && chmod +x linux-setup.sh && ./linux-setup.sh"
        wsl -d $InstanceName -u $UserName -- bash -ic $SetupCmd
    }

    Write-Host "Setup complete! You can now start the instance by running: wsl -d $InstanceName" -ForegroundColor Green
} else {
    Write-Host "Error: WSL import failed." -ForegroundColor Red
}

