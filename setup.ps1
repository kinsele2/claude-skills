#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoDir        = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginCache    = Join-Path $HOME ".claude\plugins\cache\local"
$InstalledPlugins = Join-Path $HOME ".claude\plugins\installed_plugins.json"

# Test whether this session can create symlinks (requires Admin or Developer Mode on Windows)
$canSymlink = $false
$testTarget = [System.IO.Path]::GetTempFileName()
$testLink   = $testTarget + "_link"
try {
    New-Item -ItemType SymbolicLink -Path $testLink -Target $testTarget -ErrorAction Stop | Out-Null
    Remove-Item $testLink  -Force -ErrorAction SilentlyContinue
    $canSymlink = $true
} catch {
    Write-Warning "Symlinks unavailable. Enable Windows Developer Mode (Settings > System > For developers) or run as Administrator."
    Write-Warning "Skills will be copied instead — re-run setup.ps1 after editing a SKILL.md to sync changes."
} finally {
    Remove-Item $testTarget -Force -ErrorAction SilentlyContinue
}

# Ensure installed_plugins.json exists with the right shape
if (-not (Test-Path $InstalledPlugins)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $InstalledPlugins) | Out-Null
    '{"version": 2, "plugins": {}}' | Set-Content $InstalledPlugins -Encoding UTF8
}

Get-ChildItem -Path $RepoDir -Directory | ForEach-Object {
    $skill    = $_.Name
    $skillMd  = Join-Path $_.FullName "SKILL.md"

    if (-not (Test-Path $skillMd)) { return }

    $targetDir  = Join-Path $PluginCache "$skill\1.0.0\skills\$skill"
    $pluginMeta = Join-Path $PluginCache "$skill\1.0.0\.claude-plugin"
    $pluginJson = Join-Path $pluginMeta "plugin.json"
    $targetLink = Join-Path $targetDir "SKILL.md"

    New-Item -ItemType Directory -Force -Path $targetDir  | Out-Null
    New-Item -ItemType Directory -Force -Path $pluginMeta | Out-Null

    # Write plugin.json if missing
    if (-not (Test-Path $pluginJson)) {
        $descLine = Select-String -Path $skillMd -Pattern '^description:' | Select-Object -First 1
        $descText = if ($descLine) { $descLine.Line -replace '^description:\s*', '' } else { "$skill skill" }
        @"
{
  "name": "$skill",
  "version": "1.0.0",
  "description": "$descText"
}
"@ | Set-Content $pluginJson -Encoding UTF8
    }

    # Create symlink or copy
    $existing     = if (Test-Path $targetLink -PathType Leaf) { Get-Item $targetLink -Force } else { $null }
    $alreadyLinked = $existing -and ($existing.LinkType -eq 'SymbolicLink') -and ($existing.Target -eq $skillMd)

    if ($alreadyLinked) {
        Write-Host "  already linked: $skill"
    } elseif ($canSymlink) {
        if (Test-Path $targetLink) { Remove-Item $targetLink -Force }
        New-Item -ItemType SymbolicLink -Path $targetLink -Target $skillMd | Out-Null
        Write-Host "  linked: $skill"
    } else {
        Copy-Item $skillMd $targetLink -Force
        Write-Host "  copied: $skill"
    }

    # Register in installed_plugins.json if not present
    $json = Get-Content $InstalledPlugins -Raw | ConvertFrom-Json
    $key  = "${skill}@local"
    if (-not $json.plugins.PSObject.Properties[$key]) {
        $now         = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z")
        $installPath = Join-Path $PluginCache "$skill\1.0.0"
        $entry = @([PSCustomObject]@{
            scope       = 'user'
            installPath = $installPath
            version     = '1.0.0'
            installedAt = $now
            lastUpdated = $now
        })
        $json.plugins | Add-Member -NotePropertyName $key -NotePropertyValue $entry -Force
        $json | ConvertTo-Json -Depth 10 | Set-Content $InstalledPlugins -Encoding UTF8
        Write-Host "  registered: $skill"
    }
}

Write-Host ""
Write-Host "Done. Restart Claude Code to pick up any new skills."
