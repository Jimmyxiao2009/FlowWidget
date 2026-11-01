$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $projectDir

$pythonLauncher = Get-Command py -ErrorAction SilentlyContinue
if ($null -ne $pythonLauncher) {
    $pythonArgs = @()
    foreach ($version in @("3.13", "3.12", "3.11", "3.10")) {
        & py "-$version" -c "import sys" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $pythonArgs = @("-$version")
            break
        }
    }
    if ($pythonArgs.Count -eq 0) {
        $pythonArgs = @("-3")
    }
    & py @pythonArgs -m venv .venv
} else {
    & python -m venv .venv
}

$venvPython = Join-Path $projectDir ".venv\Scripts\python.exe"
& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install -e "."

Write-Host "开发环境已准备完成。运行 .\start-dev.ps1 启动 FlowWidget。"
