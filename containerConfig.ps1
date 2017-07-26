#  Arguments : HostName, specifies the FQDN of machine or domain
param
(
    [string] $HostName = $(throw "HostName is required.")
)

$Logfile = "C:\containerConfig.log"

function LogWrite {
   Param ([string]$logstring)
   $now = Get-Date -format s
   Add-Content $Logfile -value "$now $logstring"
   Write-Host $logstring
}

function Get-HostToIP($hostname) {
  $result = [system.Net.Dns]::GetHostByName($hostname)
  $result.AddressList | ForEach-Object {$_.IPAddressToString }
}

$PublicIPAddress = Get-HostToIP($HostName)

LogWrite "containerConfig.ps1"
LogWrite "HostName = $($HostName)"
LogWrite "PublicIPAddress = $($PublicIPAddress)"
LogWrite "USERPROFILE = $($env:USERPROFILE)"
LogWrite "pwd = $($pwd)"

# Set Docker Firewall Rules:
if (!(Get-NetFirewallRule | where {$_.Name -eq "Docker"})) {
  New-NetFirewallRule -Name "Docker" -DisplayName "Docker" -Protocol tcp -LocalPort 2376
}

if (!(Test-Path $env:USERPROFILE\.docker)) {
  mkdir $env:USERPROFILE\.docker
}

$ips = ((Get-NetIPAddress -AddressFamily IPv4).IPAddress) -Join ','
LogWrite "Creating certs for $ips,$PublicIPAddress"

docker run --rm `
  -e SERVER_NAME=$(hostname) `
  -e IP_ADDRESSES=$ips,$PublicIPAddress `
  -v "C:\ProgramData\docker:C:\ProgramData\docker" `
  -v "$env:USERPROFILE\.docker:C:\Users\ContainerAdministrator\.docker" `
  stefanscherer/dockertls-windows

# get rid of old -H options that would conflict with daemon.json
stop-service docker
dockerd --unregister-service
dockerd --register-service

# add group docker in daemon.json as it got lost with the unregister-service call
$daemonJson = "C:\ProgramData\docker\config\daemon.json"
$config = (Get-Content $daemonJson) -join "`n" | ConvertFrom-Json
$config = $config | Add-Member(@{ `
  group = "docker" `
  }) -Force -PassThru
LogWrite "`n=== Creating / Updating $daemonJson"
$config | ConvertTo-Json | Set-Content $daemonJson -Encoding Ascii

LogWrite "updating to latest version of Docker Engine and Docker Compose"
$DOCKER_COMPOSE_VERSION="1.14"
$DOCKER_VERSION="v17.03.2-ce"

Invoke-WebRequest https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Windows-x86_64.exe -UseBasicParsing -OutFile $env:ProgramFiles\docker\docker-compose.exe

if (test-path $env:TEMP\docker.zip) {rm $env:TEMP\docker.zip}
Invoke-WebRequest "https://get.docker.com/builds/Windows/x86_64/docker-${DOCKER_VERSION}.zip" -OutFile "$env:TEMP\docker.zip" -UseBasicParsing
Expand-Archive -Path "$env:TEMP\docker.zip" -DestinationPath $env:ProgramFiles -Force
docker version
docker-compose version

LogWrite "Contents of $daemonJson"
LogWrite ((Get-Content $daemonJson) -join "`n")

start-service docker

LogWrite (docker version)
LogWrite (docker info)
LogWrite (docker-compose version)

# Install Chocolatey
#iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
# install docker tools
#choco install -y docker-machine -version 0.9.0
#choco install -y docker-compose -version 1.10.0
