# Faz o Jarvis ficar esperando as duas palmas sempre que o Windows iniciar.
# Ativar:     powershell -ExecutionPolicy Bypass -File .\ativar-inicio.ps1
# Desativar:  powershell -ExecutionPolicy Bypass -File .\ativar-inicio.ps1 -Desativar
param([switch]$Desativar)

$ErrorActionPreference = "Stop"
$Kit = $PSScriptRoot
$Atalho = Join-Path ([Environment]::GetFolderPath("Startup")) "Jarvis Palmas.lnk"

if ($Desativar) {
    if (Test-Path $Atalho) { Remove-Item $Atalho }
    Write-Host "Desativado. O Jarvis nao vai mais iniciar com o Windows."
    Write-Host "Se ele estiver rodando agora, feche a janela 'Jarvis Palmas' na barra de tarefas."
    exit 0
}

$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($Atalho)
$lnk.TargetPath = Join-Path $Kit "palmas.cmd"
$lnk.WorkingDirectory = $Kit
$lnk.WindowStyle = 7          # inicia minimizado
$lnk.Description = "Jarvis: acorda com duas palmas"
$lnk.Save()

Write-Host "Pronto. Atalho criado em: $Atalho" -ForegroundColor Green
Write-Host "Iniciando agora (janela minimizada na barra de tarefas)..."
Start-Process $Atalho
Write-Host "Bata duas palmas para testar. Nao mova nem apague a pasta $Kit."
