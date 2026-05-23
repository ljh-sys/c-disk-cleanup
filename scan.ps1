# C Drive Cleanup Scanner v2
param([string]$OutputPath = "")

if ($OutputPath -eq "") { $OutputPath = "$env:USERPROFILE\.cleanup\data.json" }

$ErrorActionPreference = "SilentlyContinue"
$StartTime = Get-Date
$User = $env:USERNAME
$UP = $env:USERPROFILE

$ODir = Split-Path $OutputPath -Parent
if (!(Test-Path $ODir)) { New-Item -ItemType Directory -Path $ODir -Force | Out-Null }

# Load whitelist
$WF = "$ODir\whitelist.json"
$WL = @()
if (Test-Path $WF) { try { $WL = @(Get-Content $WF -Raw | ConvertFrom-Json) } catch { } }

# C drive info
$CD = Get-PSDrive C
$CT = [math]::Round($CD.Used / 1GB + $CD.Free / 1GB)
$CU = [math]::Round($CD.Used / 1GB, 1)
$CF = [math]::Round($CD.Free / 1GB, 1)
$CP = [math]::Round(($CD.Used / ($CD.Used + $CD.Free)) * 100)

# Whitelist check
function TW { param([string]$P); foreach ($w in $WL) { if ($P -like "*$w*") { return $true } }; return $false }

Write-Output "Scanning C drive (parallel jobs)..."

# ---- PARALLEL JOBS ----
$Jobs = @()

$Jobs += Start-Job -Name "Local" {
    $p = "$env:USERPROFILE\AppData\Local"
    Get-ChildItem $p -Directory -EA 0 | ForEach {
        $s = (Get-ChildItem $_.FullName -Recurse -File -EA 0 | Measure -Property Length -Sum).Sum
        if ($s -gt 1MB) { @{P=$_.FullName; S=[math]::Round($s/1MB,1); N=$_.Name} }
    } | Sort { -$_.S } | Select -First 30 | ConvertTo-Json -Compress
}

$Jobs += Start-Job -Name "Roaming" {
    $p = "$env:USERPROFILE\AppData\Roaming"
    Get-ChildItem $p -Directory -EA 0 | ForEach {
        $s = (Get-ChildItem $_.FullName -Recurse -File -EA 0 | Measure -Property Length -Sum).Sum
        if ($s -gt 1MB) { @{P=$_.FullName; S=[math]::Round($s/1MB,1); N=$_.Name} }
    } | Sort { -$_.S } | Select -First 30 | ConvertTo-Json -Compress
}

$Jobs += Start-Job -Name "LocalLow" {
    $p = "$env:USERPROFILE\AppData\LocalLow"
    Get-ChildItem $p -Directory -EA 0 | ForEach {
        $s = (Get-ChildItem $_.FullName -Recurse -File -EA 0 | Measure -Property Length -Sum).Sum
        if ($s -gt 1MB) { @{P=$_.FullName; S=[math]::Round($s/1MB,1); N=$_.Name} }
    } | Sort { -$_.S } | Select -First 15 | ConvertTo-Json -Compress
}

$Jobs += Start-Job -Name "UserDirs" {
    $p = "$env:USERPROFILE"
    Get-ChildItem $p -Directory -EA 0 | Where { $_.Name -notin @('AppData','.ssh','.gnupg','Desktop') } | ForEach {
        $s = (Get-ChildItem $_.FullName -Recurse -File -EA 0 | Measure -Property Length -Sum).Sum
        if ($s -gt 0.1MB) { @{P=$_.FullName; S=[math]::Round($s/1MB,1); N=$_.Name} }
    } | Sort { -$_.S } | Select -First 40 | ConvertTo-Json -Compress
}

$Jobs += Start-Job -Name "DotDirs" {
    $p = "$env:USERPROFILE"
    Get-ChildItem $p -Directory -EA 0 | Where { $_.Name -match '^\.' } | ForEach {
        $s = (Get-ChildItem $_.FullName -Recurse -File -EA 0 | Measure -Property Length -Sum).Sum
        if ($s -gt 0) { @{P=$_.FullName; S=[math]::Round($s/1MB,1); N=$_.Name} }
    } | Sort { -$_.S } | ConvertTo-Json -Compress
}

$Jobs += Start-Job -Name "ProgramData" {
    Get-ChildItem "C:\ProgramData" -Directory -EA 0 | ForEach {
        $s = (Get-ChildItem $_.FullName -Recurse -File -EA 0 | Measure -Property Length -Sum).Sum
        if ($s -gt 10MB) { @{P=$_.FullName; S=[math]::Round($s/1MB,1); N=$_.Name} }
    } | Sort { -$_.S } | Select -First 20 | ConvertTo-Json -Compress
}

$Jobs += Start-Job -Name "SystemFiles" {
    $i = @()
    @("C:\pagefile.sys","C:\hiberfil.sys","C:\swapfile.sys") | ForEach {
        if (Test-Path $_) { $i += @{P=$_; S=[math]::Round((Get-Item $_).Length/1MB,1); N=(Split-Path $_ -Leaf)} }
    }
    $i | ConvertTo-Json -Compress
}

$Jobs += Start-Job -Name "WinDirs" {
    $i = @()
    @("C:\Windows\Temp","C:\Windows\Installer","C:\Windows\SoftwareDistribution\Download","C:\Windows\Prefetch","C:\Windows\Logs","C:\Windows\WinSxS") | ForEach {
        if (Test-Path $_) {
            $s = (Get-ChildItem $_ -Recurse -File -EA 0 | Measure -Property Length -Sum).Sum
            $i += @{P=$_; S=[math]::Round($s/1MB,1); N=(Split-Path $_ -Leaf)}
        }
    }
    # Recycle Bin (system-wide)
    if (Test-Path "C:\`$Recycle.Bin") {
        $s = (Get-ChildItem "C:\`$Recycle.Bin" -Recurse -File -EA 0 | Measure -Property Length -Sum).Sum
        $i += @{P="C:\`$Recycle.Bin"; S=[math]::Round($s/1MB,1); N="Recycle Bin"}
    }
    # Windows.old
    if (Test-Path "C:\Windows.old") {
        $s = (Get-ChildItem "C:\Windows.old" -Recurse -File -EA 0 | Measure -Property Length -Sum).Sum
        $i += @{P="C:\Windows.old"; S=[math]::Round($s/1MB,1); N="Windows.old"}
    }
    $i | ConvertTo-Json -Compress
}

$Jobs += Start-Job -Name "ProgramFiles" {
    $i = @()
    @("C:\Program Files","C:\Program Files (x86)") | ForEach {
        if (Test-Path $_) {
            Get-ChildItem $_ -Directory -EA 0 | ForEach {
                $s = (Get-ChildItem $_.FullName -Recurse -File -EA 0 | Measure -Property Length -Sum).Sum
                if ($s -gt 100MB) { $i += @{P=$_.FullName; S=[math]::Round($s/1MB,1); N=$_.Name} }
            }
        }
    }
    ($i | Sort { -$_.S } | Select -First 25) | ConvertTo-Json -Compress
}

# ---- COLLECT RESULTS ----
$JobResults = @()
foreach ($job in $Jobs) {
    $r = $job | Receive-Job -Wait -AutoRemoveJob
    $JobResults += @{ Name = $job.Name; Data = $r }
}

Write-Output "Categorizing..."

# ---- CATEGORIZE ----
$Items = @()
foreach ($jr in $JobResults) {
    $jsonStr = $jr.Data -join "`n"
    if ([string]::IsNullOrWhiteSpace($jsonStr)) { continue }
    try {
        $entries = $jsonStr | ConvertFrom-Json
        if ($entries -isnot [array]) { $entries = @($entries) }
        foreach ($e in $entries) {
            $path = $e.P; $size = $e.S
            if ($size -le 0.1) { continue }

            # Check whitelist
            if (TW $path) { continue }

            # Category by location only — risk + description left to AI
            if ($path -match "\\AppData\\Local\\") { $cat = "App Local" }
            elseif ($path -match "\\AppData\\Roaming\\") { $cat = "App Roaming" }
            elseif ($path -match "\\AppData\\LocalLow\\") { $cat = "App LocalLow" }
            elseif ($path -match "\\ProgramData\\") { $cat = "ProgramData" }
            elseif ($path -match "\\Program Files") { $cat = "Program" }
            elseif ($path -match "\\Windows") { $cat = "System" }
            elseif ($path -match "^C:\\[^\\]+$") { $cat = "System" }
            elseif ($path -match "^\.") { $cat = "User Config" }
            else { $cat = "Other" }

            $lm = try { (Get-Item $path).LastWriteTime.ToString("yyyy-MM-dd") } catch { "" }

            $Items += @{
                path = $path.Replace($UP, "~").Replace("\", "/")
                real_path = $path
                size_mb = $size
                size_display = if ($size -ge 1024) { "$([math]::Round($size/1024,1)) GB" } else { "$([math]::Round($size,1)) MB" }
                category = $cat
                risk = "confirm"
                description = ""
                last_modified = $lm
            }
        }
    } catch { }
}

# System files
if (Test-Path "C:\pagefile.sys") {
    $s = [math]::Round((Get-Item "C:\pagefile.sys").Length / 1GB, 1)
    $Items += @{path="C:/pagefile.sys"; real_path="C:\pagefile.sys"; size_mb=$s*1024; size_display="$s GB"; category="System"; risk="confirm"; description=""; last_modified=""}
}
if (Test-Path "C:\hiberfil.sys") {
    $s = [math]::Round((Get-Item "C:\hiberfil.sys").Length / 1GB, 1)
    $Items += @{path="C:/hiberfil.sys"; real_path="C:\hiberfil.sys"; size_mb=$s*1024; size_display="$s GB"; category="System"; risk="confirm"; description=""; last_modified=""}
}

# Deduplicate & sort by size descending
$Items = $Items | Sort-Object { $_.real_path } -Unique
$Items = $Items | Sort-Object { -$_.size_mb }

# ---- REGISTRY STARTUP ORPHANS ----
$StartupOrphans = @()
try {
    $rk = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $rp = Get-ItemProperty $rk -EA 0
    if ($rp) {
        $pn = $rp.PSObject.Properties | Where { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') }
        foreach ($prop in $pn) {
            $ep = $prop.Value -replace '"',''
            $exists = Test-Path $ep -EA 0
            if (-not $exists) {
                $StartupOrphans += @{
                    path = "Registry://HKCU/Run/$($prop.Name)"
                    real_path = "Registry://HKCU/Run/$($prop.Name)"
                    size_mb = 0; size_display = "N/A"
                    category = "Registry"; risk = "confirm"
                    description = ""
                    last_modified = ""
                }
            }
        }
    }
} catch { }

# ---- BUILD OUTPUT ----
$ScanDur = [math]::Round(($(Get-Date) - $StartTime).TotalSeconds)
$SafeI = @($Items | Where { $_.risk -eq "safe" })
$ConfirmI = @($Items | Where { $_.risk -eq "confirm" })
$DangerI = @($Items | Where { $_.risk -eq "danger" })

$SafeSum = 0; foreach ($i in $SafeI) { $SafeSum += $i.size_mb }
$ConfirmSum = 0; foreach ($i in $ConfirmI) { $ConfirmSum += $i.size_mb }
$DangerSum = 0; foreach ($i in $DangerI) { $DangerSum += $i.size_mb }

$Output = @{
    scan_time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    scan_duration_seconds = $ScanDur
    c_drive = @{
        total_gb = $CT
        used_gb = $CU
        free_gb = $CF
        usage_percent = $CP
        driver = "C:"
    }
    summary = @{
        safe_items = $SafeI.Count
        safe_total_mb = [math]::Round($SafeSum)
        confirm_items = $ConfirmI.Count
        confirm_total_mb = [math]::Round($ConfirmSum)
        danger_items = $DangerI.Count
        danger_total_mb = [math]::Round($DangerSum)
        total_items = $Items.Count
    }
    items = @($Items)
    startup_orphans = @($StartupOrphans)
}

$Output | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8 -Force

# ---- GENERATE HTML REPORT via Python ----
$ReportPath = "$env:USERPROFILE\Desktop\C盘清理分析报告.html"
$PyScript = Join-Path $PSScriptRoot "make-report.py"
if (Test-Path $PyScript) {
    $pyResult = python $PyScript 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Output "  Report saved: $ReportPath"
        $pyOutput = "$pyResult"
        if ($pyOutput -match "AI descriptions needed: (\d+)") {
            Write-Output "  ⚠ $($matches[1]) items need AI descriptions — run skill again to generate"
            Write-Output "     → C:\Users\$env:USERNAME\.cleanup\ai-needed.json"
        }
    } else {
        Write-Output "  WARNING: Report generation failed: $pyResult"
    }
} else {
    Write-Output "  WARNING: make-report.py not found, skipping report generation"
}

Write-Output ""
Write-Output "============================================"
Write-Output "  Scan Complete! ($ScanDur sec)"
Write-Output "  C: ${CU}GB / ${CT}GB (${CP}%)"
Write-Output "  Safe to delete: $($SafeI.Count) items ($([math]::Round($SafeSum)) MB)"
Write-Output "  Need confirm: $($ConfirmI.Count) items ($([math]::Round($ConfirmSum)) MB)"
Write-Output "============================================"

# ---- OPEN REPORT ----
if (Test-Path $ReportPath) { Start-Process $ReportPath }
