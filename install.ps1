# LearnForge one-line installer for Windows PowerShell.
#   irm https://YOUR-HOST/install.ps1 | iex
# Set $ZipUrl below (or pass it via $env:LEARNFORGE_ZIP) to where learnforge.zip is hosted.
$ZipUrl  = if ($env:LEARNFORGE_ZIP) { $env:LEARNFORGE_ZIP } else { 'https://REPLACE-ME/learnforge.zip' }
$Dest    = Join-Path $HOME 'learnforge'
$ErrorActionPreference = 'Stop'

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }

if ($ZipUrl -like '*REPLACE-ME*') { throw 'Installer not configured: set $env:LEARNFORGE_ZIP or edit $ZipUrl.' }

Step 'Checking Node.js (v22+ required)'
function NodeOk { try { [int]((node -v) -replace '^v(\d+).*','$1') -ge 22 } catch { $false } }
if (-not (NodeOk)) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host 'Installing Node.js LTS with winget...'
    winget install -e --id OpenJS.NodeJS --accept-package-agreements --accept-source-agreements
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
  }
  if (-not (NodeOk)) { throw 'Node.js 22+ is required. Install it from https://nodejs.org, reopen PowerShell, and run this again.' }
}

Step "Downloading LearnForge to $Dest"
$zip = Join-Path $env:TEMP 'learnforge.zip'
Invoke-WebRequest $ZipUrl -OutFile $zip -UseBasicParsing
$tmp = Join-Path $env:TEMP 'learnforge-extract'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
Expand-Archive $zip -DestinationPath $tmp -Force
$src = if (Test-Path (Join-Path $tmp 'learnforge')) { Join-Path $tmp 'learnforge' } else { $tmp }
New-Item -ItemType Directory -Force $Dest | Out-Null
Copy-Item "$src\*" $Dest -Recurse -Force
Remove-Item $zip, $tmp -Recurse -Force

Set-Location $Dest
Step 'Installing and building (about a minute)'
npm run setup

$envFile = Join-Path $Dest '.env'
if (-not (Test-Path $envFile)) {
  Step 'Choose how LearnForge talks to Claude'
  Write-Host '  1) Claude Pro/Max subscription (log in with your claude.ai account)'
  Write-Host '  2) Anthropic API key (pay-as-you-go)'
  Write-Host '  3) Offline mode (no AI, simple demo lessons)'
  $choice = Read-Host 'Type 1, 2 or 3'
  switch ($choice) {
    '1' {
      if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Write-Host 'Installing Claude Code...'
        npm install -g @anthropic-ai/claude-code
        $env:Path += ';' + (npm config get prefix)
      }
      Write-Host "`nA login prompt will open. Sign in with your Claude account, then type /exit to continue." -ForegroundColor Yellow
      claude
      'LF_PROVIDER=claude-code' | Set-Content $envFile -Encoding ascii
    }
    '2' {
      $key = Read-Host 'Paste your Anthropic API key'
      "ANTHROPIC_API_KEY=$($key.Trim())" | Set-Content $envFile -Encoding ascii
    }
    default { 'ANTHROPIC_API_KEY=' | Set-Content $envFile -Encoding ascii }
  }
}

Step 'Starting LearnForge at http://localhost:8787  (Ctrl+C to stop)'
Start-Process 'http://localhost:8787'
npm start
