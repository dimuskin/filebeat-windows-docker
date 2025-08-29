FROM mcr.microsoft.com/windows/servercore:ltsc2019 AS core
ARG FILEBEAT_VERSION
ARG FILEBEAT_SHA512
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN $url = ('https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-{0}-windows-x86_64.zip' -f $env:FILEBEAT_VERSION); \
    Write-Host ('Downloading {0} to filebeat.zip ...' -f $url); \
    Invoke-WebRequest -Uri $url -OutFile 'filebeat.zip' -TimeoutSec 300; \
    \
    $sha512 = $env:FILEBEAT_SHA512; \
    Write-Host ('Verifying sha512 ({0}) ...' -f $sha512); \
    if ((Get-FileHash filebeat.zip -Algorithm sha512).Hash -ne $sha512) { \
        Write-Host 'FAILED!'; \
        exit 1; \
    }; \
    \
    New-Item -Path 'c:\' -Name 'filebeat' -ItemType 'directory'; \
    Write-Host 'Expanding filebeat.zip ...'; \
    Expand-Archive filebeat.zip -DestinationPath C:\filebeat; \
    \
    Write-Host 'Removing filebeat.zip ...'; \
    Remove-Item filebeat.zip -Force; \
    \
    Write-Host 'Completed installing filebeat.';

FROM mcr.microsoft.com/windows/nanoserver:ltsc2019

ARG FILEBEAT_VERSION
ARG MACHINEGUID=FCKGW-RHQQ2-YXRKT-8TG6W-2B7Q8

COPY --from=core /filebeat/filebeat-${FILEBEAT_VERSION}-windows-x86_64 /filebeat
COPY --from=core /Windows/System32/netapi32.dll /Windows/System32/netapi32.dll

USER ContainerAdministrator

RUN reg add "HKLM\SOFTWARE\Microsoft\Cryptography" /f 
RUN reg add "HKLM\SOFTWARE\Microsoft\Cryptography" /v MachineGuid /t REG_SZ /d ${MACHINEGUID} /f

ENTRYPOINT [ "c:\\filebeat\\filebeat.exe", "-c", "c:\\etc\\filebeat.yml", "-e" ]