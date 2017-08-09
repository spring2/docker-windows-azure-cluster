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

LogWrite (docker version)
LogWrite (docker info)

# Set Docker Firewall Rules:
if (!(Get-NetFirewallRule | where {$_.Name -eq "Docker"})) {
  New-NetFirewallRule -Name "Docker-tls" -DisplayName "Docker-tls" -Protocol tcp -LocalPort 2376
  New-NetFirewallRule -Name "Docker" -DisplayName "Docker" -Protocol tcp -LocalPort 2375
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


LogWrite "Install chocolatey and az cli"
iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
choco install -y azure-cli
choco install -y windowsazurepowershell

LogWrite "updating to latest version of Docker Engine and Docker Compose"
$DOCKER_COMPOSE_VERSION="1.14.0"
$DOCKER_VERSION="17.05.0-ce"

Invoke-WebRequest https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Windows-x86_64.exe -UseBasicParsing -OutFile $env:ProgramFiles\docker\docker-compose.exe

if (test-path $env:TEMP\docker.zip) {rm $env:TEMP\docker.zip}
Invoke-WebRequest "https://get.docker.com/builds/Windows/x86_64/docker-${DOCKER_VERSION}.zip" -OutFile "$env:TEMP\docker.zip" -UseBasicParsing
if (test-path $env:TEMP\docker.zip) {Expand-Archive -Path "$env:TEMP\docker.zip" -DestinationPath $env:ProgramFiles -Force}

LogWrite "Contents of $daemonJson"
LogWrite ((Get-Content $daemonJson) -join "`n")

LogWrite "fix daemon.config to be without tls for now"
$config = @"
{
    "hosts":  [
                  "tcp://0.0.0.0:2375",
                  "npipe://"
              ],
    "group":  "docker",
    "dns": ["10.0.0.6", "168.63.129.16", "8.8.8.8"],
    "dns-search": ["service.consul"],
    "labels": ["os=windows"],
    "fixed-cidr": "172.16.0.0/16"
}
"@

$config | Out-File $daemonJson -Encoding ASCII

LogWrite "Contents of $daemonJson"
LogWrite ((Get-Content $daemonJson) -join "`n")

start-service docker

LogWrite (docker version)
LogWrite (docker info)
LogWrite (docker-compose version)

LogWrite "show that TLS works"
LogWrite (docker --tlsverify --tlscacert=C:\Windows\system32\config\systemprofile\.docker\ca.pem --tlscert=C:\Windows\system32\config\systemprofile\.docker\cert.pem --tlskey=C:\Windows\system32\config\systemprofile\.docker\key.pem -H=tcp://127.0.0.1:2376 version)

LogWrite "check for az"
LogWrite (az --help)