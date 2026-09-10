#Requires -Version 5.1
<#
.SYNOPSIS
  Pack a release zip without modifying personal AppData settings.

.DESCRIPTION
  - Preserves all personal settings, configs and logs
  - Zips this project folder with fixed 1980-01-01 timestamps (no local metadata)
  - Output: sibling folder "Hikari's Edited Fisch Macro <version>.zip"
#>
[CmdletBinding()]
param(
    [switch]$SkipWipe,
    [string]$OutDir
)

$ErrorActionPreference = "Stop"

$ProjectRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$VersionPath = Join-Path $ProjectRoot "version.txt"
if (!(Test-Path -LiteralPath $VersionPath)) {
    throw "version.txt not found: $VersionPath"
}
$Version = (Get-Content -LiteralPath $VersionPath -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($Version)) {
    throw "version.txt is empty"
}

$FolderName = Split-Path -Leaf $ProjectRoot
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Split-Path -Parent $ProjectRoot
}
$ZipPath = Join-Path $OutDir ("{0} {1}.zip" -f $FolderName, $Version)

$FixedTime = [datetime]::new(1980, 1, 1, 0, 0, 0, [DateTimeKind]::Unspecified)

Write-Host "== Hikari release pack =="
Write-Host "Project : $ProjectRoot"
Write-Host "Version : $Version"
Write-Host "Output  : $ZipPath"

Write-Host "Personal AppData settings are preserved."

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Staging = Join-Path ([System.IO.Path]::GetTempPath()) ("hikari-pack-" + [guid]::NewGuid().ToString("n"))
$StagingRoot = Join-Path $Staging $FolderName
New-Item -ItemType Directory -Path $StagingRoot -Force | Out-Null

try {
    # Copy project; skip this script's own staging leftovers and common junk
    $excludeNames = @(
        ".git", ".vs", ".vscode", ".idea",
        "node_modules", "__pycache__", ".swarm", ".hive-mind"
    )
    Get-ChildItem -LiteralPath $ProjectRoot -Force | ForEach-Object {
        if ($excludeNames -contains $_.Name) { return }
        if ($_.Name -like "*.zip") { return }
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $StagingRoot $_.Name) -Recurse -Force
    }

    Get-ChildItem -LiteralPath $StagingRoot -Recurse -Force | ForEach-Object {
        $_.CreationTime = $FixedTime
        $_.LastWriteTime = $FixedTime
        $_.LastAccessTime = $FixedTime
    }

    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }

    $fs = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::CreateNew)
    try {
        $zip = New-Object System.IO.Compression.ZipArchive(
            $fs,
            [System.IO.Compression.ZipArchiveMode]::Create,
            $false
        )
        try {
            foreach ($f in (Get-ChildItem -LiteralPath $Staging -Recurse -File -Force)) {
                $rel = $f.FullName.Substring($Staging.Length).TrimStart("\", "/")
                $entryName = ($rel -replace "\\", "/")
                $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = [DateTimeOffset]$FixedTime
                $out = $entry.Open()
                try {
                    $ins = [System.IO.File]::OpenRead($f.FullName)
                    try { $ins.CopyTo($out) } finally { $ins.Dispose() }
                } finally { $out.Dispose() }
            }
        } finally {
            $zip.Dispose()
        }
    } finally {
        $fs.Dispose()
    }

    $zi = Get-Item -LiteralPath $ZipPath
    $zi.CreationTime = $FixedTime
    $zi.LastWriteTime = $FixedTime
    $zi.LastAccessTime = $FixedTime

    $entryCount = 0
    $zr = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try { $entryCount = $zr.Entries.Count } finally { $zr.Dispose() }

    Write-Host "Done."
    Write-Host ("Zip     : {0} ({1:N0} bytes, {2} entries)" -f $ZipPath, $zi.Length, $entryCount)
    Write-Host "Timestamps normalized to 1980-01-01"
}
finally {
    if (Test-Path -LiteralPath $Staging) {
        Remove-Item -LiteralPath $Staging -Recurse -Force
    }
}
