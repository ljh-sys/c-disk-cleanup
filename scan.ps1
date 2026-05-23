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

# Load history
$HF = "$ODir\history.json"
$Hist = @()
if (Test-Path $HF) { try { $Hist = @(Get-Content $HF -Raw | ConvertFrom-Json) } catch { } }

# C drive info
$CD = Get-PSDrive C
$CT = [math]::Round($CD.Used / 1GB + $CD.Free / 1GB)
$CU = [math]::Round($CD.Used / 1GB, 1)
$CF = [math]::Round($CD.Free / 1GB, 1)
$CP = [math]::Round(($CD.Used / ($CD.Used + $CD.Free)) * 100)

# Whitelist check
function TW { param([string]$P); foreach ($w in $WL) { if ($P -like "*$w*") { return $true } }; return $false }

# Match patterns: Match regex, Category, Description, Risk
$SafeP = @(
    @{M="CrashDumps$"; C="CrashDump"; D="Crash dump files"; R="safe"},
    @{M="D3DSCache$"; C="D3D Cache"; D="Direct3D shader cache"; R="safe"},
    @{M="\.cache$"; C="Cache"; D="Application cache"; R="safe"},
    @{M="\\Temp$"; C="Temp"; D="Temporary files"; R="safe"},
    @{M="\\logs$"; C="Logs"; D="Application logs"; R="safe"},
    @{M="npm-cache$"; C="npm"; D="npm package cache"; R="safe"},
    @{M="pip\\cache$"; C="pip"; D="Python pip cache"; R="safe"},
    @{M="go-build$"; C="Go Build"; D="Go build cache"; R="safe"},
    @{M="\.gradle\\caches$"; C="Gradle"; D="Gradle build cache"; R="safe"},
    @{M="\.m2\\repository$"; C="Maven"; D="Maven local repo"; R="safe"},
    @{M="Package Cache$"; C="MSI Cache"; D="Windows installer cache"; R="safe"},
    @{M="\\Cache$"; C="Cache"; D="Application cache"; R="safe"},
    @{M="Cache_Data$"; C="Browser"; D="Chrome browser cache"; R="safe"},
    @{M="CachedData$"; C="Cache"; D="Cached data"; R="safe"},
    @{M="CachedExtensionVSIXs$"; C="VS Code"; D="VS Code extension cache"; R="safe"}
)

$ConfirmP = @(
    @{M="\\Tencent$"; C="Tencent"; D="QQ/WeChat data - chat history inside"; R="confirm"},
    @{M="\\QQ$"; C="QQ"; D="QQ chat data"; R="confirm"},
    @{M="\\JetBrains$"; C="JetBrains"; D="JetBrains IDE data"; R="confirm"},
    @{M="\\Docker$"; C="Docker"; D="Docker images & containers"; R="confirm"},
    @{M="\\MetaQuotes$"; C="MT5"; D="MetaTrader 5 trading data"; R="confirm"},
    @{M="\\LarkShell$"; C="Feishu/Lark"; D="Feishu app data"; R="confirm"},
    @{M="\\DingTalk$"; C="DingTalk"; D="DingTalk app data"; R="confirm"},
    @{M="\.jdks$"; C="JDK"; D="Java Development Kit installs"; R="confirm"},
    @{M="\.rustup$"; C="Rust"; D="Rust toolchains"; R="confirm"},
    @{M="\\Steam$"; C="Steam"; D="Steam game platform"; R="confirm"},
    @{M="\\Battle\.net$"; C="Battle.net"; D="Blizzard Battle.net"; R="confirm"},
    @{M="\.docker$"; C="Docker"; D="Docker data directory"; R="confirm"},
    @{M="\.pyenv$"; C="pyenv"; D="Python version manager"; R="confirm"},
    @{M="\.lingma$"; C="Lingma AI"; D="Tongyi Lingma AI plugin"; R="confirm"},
    @{M="\.codebuddy$"; C="CodeBuddy"; D="CodeBuddy AI assistant"; R="confirm"},
    @{M="\.gemini$"; C="Gemini"; D="Gemini CLI data"; R="confirm"},
    @{M="\.claude$"; C="Claude"; D="Claude Code data"; R="confirm"}
)

$DangerP = @(
    @{M="NTUSER\.DAT"; C="Registry"; D="WINDOWS REGISTRY Hive - DO NOT DELETE"; R="danger"},
    @{M="system32$"; C="System"; D="Windows system files - DO NOT DELETE"; R="danger"},
    @{M="\.ssh$"; C="SSH"; D="SSH keys - DO NOT DELETE"; R="danger"},
    @{M="\.gnupg$"; C="GPG"; D="GPG encryption keys - DO NOT DELETE"; R="danger"}
)

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
    Get-ChildItem $p -Directory -EA 0 | Where { $_.Name -notin @('AppData','.ssh','.gnupg') } | ForEach {
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
    @("C:\Windows\Temp","C:\Windows\Installer","C:\Windows\SoftwareDistribution\Download") | ForEach {
        if (Test-Path $_) {
            $s = (Get-ChildItem $_ -Recurse -File -EA 0 | Measure -Property Length -Sum).Sum
            $i += @{P=$_; S=[math]::Round($s/1MB,1); N=(Split-Path $_ -Leaf)}
        }
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

$Jobs += Start-Job -Name "Desktop" {
    $p = "$env:USERPROFILE\Desktop"; $i = @()
    if (Test-Path $p) {
        Get-ChildItem $p -Directory -EA 0 | ForEach {
            $s = (Get-ChildItem $_.FullName -Recurse -File -EA 0 | Measure -Property Length -Sum).Sum
            if ($s -gt 0.1MB) { $i += @{P=$_.FullName; S=[math]::Round($s/1MB,1); N="Desktop/$($_.Name)"} }
        }
        Get-ChildItem $p -File -EA 0 | Where { $_.Length -gt 5MB } | ForEach {
            $i += @{P=$_.FullName; S=[math]::Round($_.Length/1MB,1); N="Desktop/$($_.Name)"}
        }
    }
    ($i | Sort { -$_.S }) | ConvertTo-Json -Compress
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

            # Check danger (use -like with wildcard suffix)
            $isDanger = $false
            foreach ($d in $DangerP) {
                $p = $d.M -replace '\$$',''
                if ($path -like "*$p") { $isDanger = $true; break }
            }
            if ($isDanger) { continue }

            # Check whitelist
            if (TW $path) { continue }

            # Classify
            $risk = "safe"; $cat = "Cleanable"; $desc = ""
            foreach ($sp in $SafeP) {
                $p = $sp.M -replace '\$$',''
                if ($path -like "*$p") { $cat = $sp.C; $risk = $sp.R; $desc = $sp.D; break }
            }
            if ($risk -eq "safe" -and $desc -eq "") {
                foreach ($cpat in $ConfirmP) {
                    $p2 = $cpat.M -replace '\$$',''
                    if ($path -like "*$p2") { $cat = $cpat.C; $risk = $cpat.R; $desc = $cpat.D; break }
                }
            }
            if ($desc -eq "") {
                if ($path -match "\\AppData\\Local\\") { $cat = "App Local" }
                elseif ($path -match "\\AppData\\Roaming\\") { $cat = "App Roaming" }
                elseif ($path -match "\\AppData\\LocalLow\\") { $cat = "App LocalLow" }
                elseif ($path -match "\\ProgramData\\") { $cat = "ProgramData" }
                elseif ($path -match "\\Program Files") { $cat = "Program" }
                elseif ($path -match "^\.") { $cat = "User Config" }
                else { $cat = "Other" }
                $risk = "confirm"
                $desc = if ($size -gt 500) { ">500MB, review needed" } else { "Review before deleting" }
            }

            $lm = try { (Get-Item $path).LastWriteTime.ToString("yyyy-MM-dd") } catch { "" }

            $Items += @{
                path = $path.Replace($UP, "~").Replace("\", "/")
                real_path = $path
                size_mb = $size
                size_display = if ($size -ge 1024) { "$([math]::Round($size/1024,1)) GB" } else { "$([math]::Round($size,1)) MB" }
                category = $cat
                risk = $risk
                description = $desc
                last_modified = $lm
            }
        }
    } catch { }
}

# System files
if (Test-Path "C:\pagefile.sys") {
    $s = [math]::Round((Get-Item "C:\pagefile.sys").Length / 1GB, 1)
    $Items += @{path="C:/pagefile.sys"; real_path="C:\pagefile.sys"; size_mb=$s*1024; size_display="$s GB"; category="System"; risk="danger"; description="Virtual memory page file - DO NOT DELETE"; last_modified=""}
}
if (Test-Path "C:\hiberfil.sys") {
    $s = [math]::Round((Get-Item "C:\hiberfil.sys").Length / 1GB, 1)
    $Items += @{path="C:/hiberfil.sys"; real_path="C:\hiberfil.sys"; size_mb=$s*1024; size_display="$s GB"; category="System"; risk="safe"; description="Hibernate file - use powercfg -h off to remove"; last_modified=""}
}

# Deduplicate & sort
$Items = $Items | Sort-Object { $_.real_path } -Unique
$Items = $Items | Sort-Object { switch ($_.risk) { "safe" { 0 } "confirm" { 1 } "danger" { 2 } default { 3 } } }, { -$_.size_mb }

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
                    category = "Registry"; risk = "safe"
                    description = "Orphaned startup: $($prop.Name) -> $ep (file not found)"
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
    history = @($Hist)
    whitelist = $WL
}

$Output | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8 -Force

# ---- GENERATE HTML REPORT via Python ----
$ReportPath = "$env:USERPROFILE\Desktop\C盘清理分析报告.html"
$PyScript = Join-Path $PSScriptRoot "make-report.py"
if (Test-Path $PyScript) {
    $pyResult = python $PyScript 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Output "  Report saved: $ReportPath"
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
