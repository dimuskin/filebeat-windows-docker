# filebeat-windows-docker

Lightweight log shipper for Windows containers and hosts (Filebeat 8.x and 9.x) built for **Windows Server LTSC 2019** nodes.

> Windows containers must match the host OS family. This image targets **Windows Server 2019 (build 17763)**.

---

## Table of contents

* [Supported tags and platforms](#supported-tags-and-platforms)
* [What’s inside](#whats-inside)
* [Quick start (Windows host)](#quick-start-windows-host)
* [Configuration](#configuration)
* [Kubernetes (AKS) — Windows Server 2019 nodes](#kubernetes-aks--windows-server-2019-nodes)
* [Compatibility](#compatibility)
* [Troubleshooting](#troubleshooting)
* [Security & updates](#security--updates)
* [Building locally (optional)](#building-locally-optional)
* [License](#license)
* [Maintainers](#maintainers)

---

## Supported tags and platforms

* `dimuskin/filebeat-windows:8.19.3-ltsc2019` — `windows/amd64` (ServerCore 2019)
* `dimuskin/filebeat-windows:9.1.3-ltsc2019`  — `windows/amd64` (ServerCore 2019)


> TODO : If you later publish a Windows Server 2022 variant, add `:8.19.3-ltsc2022` and extend this README accordingly.

---

## What’s inside

* Base: `mcr.microsoft.com/windows/nanoserver:ltsc2019`
* Filebeat `8.19.3` extracted to `C:\filebeat`
* Default entrypoint:

  ```
  C:\filebeat\filebeat.exe -c C:\etc\filebeat.yml -e
  ```
* No opinionated config baked in — mount your `filebeat.yml`.

---

## Quick start (Windows host)

```powershell
docker pull dimuskin/filebeat-windows:8.19.3-ltsc2019

docker run --rm -it `
  -v C:\path\to\filebeat.yml:C:\etc\filebeat.yml `
  -v C:\filebeat-data:C:\filebeat\data `
  dimuskin/filebeat-windows:8.19.3-ltsc2019
```

---

## Configuration

**Common mounts**

* `C:\etc\filebeat.yml` – main config
* `C:\filebeat\data` – registry/state (persist for continuity)

**Tips**

* Filebeat supports env expansion in config (`${VAR}`).
* For Windows Event Logs, run as **ContainerAdministrator** (default on ServerCore and NanoServer).
* Add resource limits and egress rules in Kubernetes.

---

## Kubernetes (AKS) — Windows Server 2019 nodes

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat-windows-2019
  namespace: kube-system
spec:
  selector:
    matchLabels: { app: filebeat, winltc: "2019" }
  template:
    metadata:
      labels: { app: filebeat, winltc: "2019" }
    spec:
      nodeSelector:
        kubernetes.io/os: windows
        kubernetes.azure.com/os-sku: Windows2019
      tolerations:
        - key: "os"
          operator: "Equal"
          value: "Windows"
          effect: "NoSchedule"
      containers:
        - name: filebeat
          image: dimuskin/filebeat-windows:8.19.3-ltsc2019
          args: ["-c","filebeat.yml","-e"]
          volumeMounts:
            - name: cfg
              mountPath: C:\etc\filebeat.yml
              subPath: filebeat.yml
            - name: data
              mountPath: C:\filebeat\data
      volumes:
        - name: cfg
          configMap:
            name: filebeat-windows-config
        - name: data
          emptyDir: {}
```

> Create a `ConfigMap` named `filebeat-windows-config` containing your `filebeat.yml`.

---

## Compatibility

* **Use only on Windows Server 2019 nodes** (AKS Windows `os-sku: Windows2019`).
* Not compatible with Windows Server 2022 nodes (publish a separate `:ltsc2022` image for that, will add it later).

---

## Troubleshooting

* **“image is incompatible with host”** → Node pool isn’t WS2019; schedule to WS2019 or use an `ltsc2022` image on WS2022 nodes.
* **Config not found** → Ensure `filebeat.yml` is mounted at `C:\etc\filebeat.yml`.
* **No logs shipped** → Use `-e` to log to stderr, check container logs, verify inputs/paths and permissions.

---

## Security & updates

* Keep AKS node images patched.
* Rebuild and republish when Filebeat or the base image is updated.

---

## Building locally (optional)

If you’re building this image yourself, a typical `Dockerfile` pattern is:

```Dockerfile
# syntax=docker/dockerfile:1.6
FROM mcr.microsoft.com/windows/servercore:ltsc2019 AS core
ARG FILEBEAT_VERSION=8.18.5
ARG FILEBEAT_SHA512=68d607d1d9ed1a2111905978090ec2a47e24a5e22f6381e693aed081771aae2f674482d78a115dae7dbb2cf4012a517ca11c734a9bbca485e100c15cf26ff89b
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

ARG FILEBEAT_VERSION=8.18.5
ARG MACHINEGUID=FCKGW-RHQQ2-YXRKT-8TG6W-2B7Q8

COPY --from=core /filebeat/filebeat-${FILEBEAT_VERSION}-windows-x86_64 /filebeat
COPY --from=core /Windows/System32/netapi32.dll /Windows/System32/netapi32.dll

USER ContainerAdministrator

RUN reg add "HKLM\SOFTWARE\Microsoft\Cryptography" /f 
RUN reg add "HKLM\SOFTWARE\Microsoft\Cryptography" /v MachineGuid /t REG_SZ /d ${MACHINEGUID} /f

ENTRYPOINT [ "c:\\filebeat\\filebeat.exe", "-c", "c:\\etc\\filebeat.yml", "-e" ]
```

---

## License

Filebeat is provided by Elastic under its upstream license. Review the license that applies to your Filebeat version.

---

## Maintainers

Maintained by `dimuskin`.
When filing issues, include:

* Image tag:
* Node OS: Windows Server 2019
* Minimal `filebeat.yml` to reproduce
