$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvPython = Join-Path $projectDir ".venv\Scripts\python.exe"

if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
    throw "未找到项目虚拟环境，请先运行 .\setup-dev.ps1。"
}

Set-Location -LiteralPath $projectDir
& $venvPython (Join-Path $projectDir "run.py")
