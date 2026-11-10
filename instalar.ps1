# Kit de instalacao do Jarvis (OpenJarvis) para Windows.
# Uso:  powershell -ExecutionPolicy Bypass -File .\instalar.ps1
#       powershell -ExecutionPolicy Bypass -File .\instalar.ps1 -Etapa 4   (retoma da etapa 4)
#
# Cada etapa explica o que vai fazer, espera voce apertar Enter e PARA no primeiro erro.
param(
    [int]$Etapa = 1,
    [string]$Modelo = ""
)

$ErrorActionPreference = "Stop"
$Kit = $PSScriptRoot
$Raiz = if ($env:OPENJARVIS_HOME) { $env:OPENJARVIS_HOME } else { Join-Path $env:LOCALAPPDATA "OpenJarvis" }
$Src = Join-Path $Raiz "src"
$Jarvis = Join-Path $Raiz "bin\jarvis.cmd"
$ArquivoModelo = Join-Path $Kit ".modelo-escolhido.txt"

function Passo($n, $frase) {
    Write-Host ""
    Write-Host "=== Etapa $n ===" -ForegroundColor Cyan
    Write-Host $frase
    Read-Host "Aperte Enter para continuar (ou Ctrl+C para sair)" | Out-Null
}

function Falhar($n, $msg) {
    Write-Host ""
    Write-Host "ERRO na etapa $n`: $msg" -ForegroundColor Red
    Write-Host "Copie o texto acima e mande para o Claude. Depois de corrigir, retome com:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\instalar.ps1 -Etapa $n"
    exit 1
}

# Roda um programa externo e para se ele devolver erro.
function Rodar($n, [scriptblock]$cmd) {
    Write-Host "> $cmd" -ForegroundColor DarkGray
    & $cmd
    if ($LASTEXITCODE -ne 0) { Falhar $n "o comando '$cmd' terminou com codigo $LASTEXITCODE." }
}

function AtualizarPath {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path", "User")
}

function Tem($nome) { [bool](Get-Command $nome -ErrorAction SilentlyContinue) }

function PythonOk {
    foreach ($c in @("python", "py")) {
        if (Tem $c) {
            # O atalho falso da Microsoft Store escreve um aviso de erro; nao deixa isso parar o script.
            $v = ""
            $antes = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try { $v = (& $c --version 2>&1 | Out-String) } catch { $v = "" }
            $ErrorActionPreference = $antes
            if ($v -match "Python 3\.(\d+)") {
                $menor = [int]$Matches[1]
                if ($menor -ge 10 -and $menor -le 13) { Write-Host "Python OK: $($v.Trim())"; return $true }
                Write-Host "Python encontrado, mas fora da faixa 3.10-3.13: $($v.Trim())"
            }
        }
    }
    return $false
}

function BuildToolsOk {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { return $false }
    $p = & $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    return [bool]$p
}

function LerModelo {
    if ($Modelo) { return $Modelo }
    if (Test-Path $ArquivoModelo) { return (Get-Content $ArquivoModelo -Raw).Trim() }
    Falhar $Etapa "nao sei qual modelo usar. Rode de novo com:  -Etapa $Etapa -Modelo gemma4:e4b  (ou gemma4:e2b)."
}

AtualizarPath

# ---------------------------------------------------------------- 1. Diagnostico
if ($Etapa -le 1) {
    Passo 1 "Vou olhar o seu sistema, a memoria RAM e a placa de video para escolher o cerebro."
    $so = Get-CimInstance Win32_OperatingSystem
    $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    Write-Host "Sistema: $($so.Caption) ($($so.OSArchitecture))"
    Write-Host "RAM:     $ramGB GB"
    Get-CimInstance Win32_VideoController | ForEach-Object {
        Write-Host "Video:   $($_.Name)  (~$([math]::Round($_.AdapterRAM / 1GB, 1)) GB informados pelo Windows)"
    }
    $livre = [math]::Round((Get-PSDrive ($env:LOCALAPPDATA.Substring(0, 1))).Free / 1GB, 1)
    Write-Host "Disco livre em $($env:LOCALAPPDATA.Substring(0, 2)): $livre GB (precisa de uns 20 GB)"

    $sugestao = if ($ramGB -ge 15.5) { "gemma4:e4b" } else { "gemma4:e2b" }
    Write-Host ""
    Write-Host "Cerebro recomendado: $sugestao" -ForegroundColor Green
    Write-Host "  gemma4:e4b = padrao, ~9,6 GB, para 16 GB de RAM ou mais"
    Write-Host "  gemma4:e2b = menor, para computador mais fraco"
    $resp = Read-Host "Aperte Enter para aceitar '$sugestao' ou digite o outro nome"
    $escolhido = if ($resp.Trim()) { $resp.Trim() } else { $sugestao }
    Set-Content -Path $ArquivoModelo -Value $escolhido -Encoding ASCII
    Write-Host "Modelo escolhido: $escolhido"
}

# ---------------------------------------------------------------- 2. Instalacao
if ($Etapa -le 2) {
    Passo 2 "Vou conferir Python (3.10 a 3.13), git e o compilador da Microsoft, e depois rodar o instalador oficial do OpenJarvis (que tambem instala o uv e o Ollama)."

    if (-not (Tem "winget")) { Falhar 2 "o 'winget' nao existe neste Windows. Instale o 'Instalador de Aplicativo' pela Microsoft Store e rode de novo." }

    if (-not (PythonOk)) {
        Write-Host "Instalando Python 3.13..."
        Rodar 2 { winget install --id Python.Python.3.13 -e --accept-source-agreements --accept-package-agreements }
        AtualizarPath
    }
    if (-not (Tem "git")) {
        Write-Host "Instalando git..."
        Rodar 2 { winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements }
        AtualizarPath
    } else { Write-Host "git OK: $(git --version)" }

    if (-not (BuildToolsOk)) {
        Write-Host "O OpenJarvis compila uma parte em Rust e exige o 'MSVC Build Tools' (download grande, varios GB, pode demorar bastante)."
        Read-Host "Aperte Enter para instalar o Build Tools" | Out-Null
        Rodar 2 { winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-source-agreements --accept-package-agreements --override "--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended" }
    } else { Write-Host "MSVC Build Tools OK" }

    Write-Host "Baixando e rodando o instalador oficial (install.ps1)..."
    $tmp = Join-Path $env:TEMP "openjarvis-install.ps1"
    Invoke-RestMethod "https://open-jarvis.github.io/OpenJarvis/install.ps1" -OutFile $tmp
    Rodar 2 { powershell -NoProfile -ExecutionPolicy Bypass -File $tmp }
    AtualizarPath

    if (-not (Test-Path $Jarvis)) { Falhar 2 "o instalador terminou, mas nao achei $Jarvis." }
    if (-not (Tem "ollama")) {
        Write-Host "O Ollama nao veio junto; instalando..."
        Rodar 2 { winget install --id Ollama.Ollama -e --accept-source-agreements --accept-package-agreements }
        AtualizarPath
    }
    Write-Host "OpenJarvis instalado em $Raiz" -ForegroundColor Green
}

# ---------------------------------------------------------------- 3. Cerebro
if ($Etapa -le 3) {
    $m = LerModelo
    Passo 3 "Vou baixar o cerebro '$m' no Ollama (download de varios GB) e deixar ele como modelo padrao do Jarvis."
    Rodar 3 { ollama pull $m }
    Rodar 3 { & $Jarvis config set intelligence.default_model $m }
}

# ---------------------------------------------------------------- 4. Ouvidos
if ($Etapa -le 4) {
    Passo 4 "Vou instalar os extras de fala (speech e voice) no mesmo ambiente Python do OpenJarvis e configurar o reconhecimento de voz em portugues."
    Push-Location $Src
    try {
        # Repete os extras do instalador oficial (desktop / desktop-native) para o uv nao remove-los.
        Rodar 4 { uv sync --extra desktop --group desktop-native --extra speech --extra voice }
    } finally { Pop-Location }
    Rodar 4 { & $Jarvis config set speech.language pt }
    Rodar 4 { & $Jarvis config set speech.model small }
}

# ---------------------------------------------------------------- 5. Voz
if ($Etapa -le 5) {
    Passo 5 "Vou instalar o espeak-ng (o Kokoro precisa dele para portugues) e configurar a voz pf_dora."
    if (-not (Tem "espeak-ng")) {
        $pasta = Join-Path $env:ProgramFiles "eSpeak NG"
        if (-not (Test-Path (Join-Path $pasta "espeak-ng.exe"))) {
            Rodar 5 { winget install --id eSpeak-NG.eSpeak-NG -e --accept-source-agreements --accept-package-agreements }
        }
        if (-not (Test-Path (Join-Path $pasta "espeak-ng.exe"))) { Falhar 5 "instalei o espeak-ng mas nao achei $pasta\espeak-ng.exe." }
        # O instalador do espeak-ng nao se coloca no PATH; adiciona para o seu usuario.
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$pasta*") {
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$pasta", "User")
        }
        AtualizarPath
    }
    Rodar 5 { espeak-ng --version }
    Rodar 5 { & $Jarvis config set speech.tts_backend kokoro }
    Rodar 5 { & $Jarvis config set speech.voice_id pf_dora }
}

# ---------------------------------------------------------------- 6. Doctor
if ($Etapa -le 6) {
    Passo 6 "Vou rodar o 'jarvis doctor', que confere se esta tudo no lugar."
    & $Jarvis doctor
    Write-Host ""
    Write-Host "Leia o resultado acima. Se aparecer algo faltando ou em vermelho, copie e mande para o Claude" -ForegroundColor Yellow
    Write-Host "antes de continuar (retome depois com -Etapa 6 ate ficar limpo)."
    $r = Read-Host "Esta tudo limpo? (s/n)"
    if ($r -notmatch "^[sS]") { Falhar 6 "o doctor apontou pendencias." }
}

# ---------------------------------------------------------------- 7. Teste
if ($Etapa -le 7) {
    Passo 7 "Vou fazer uma pergunta de teste ao Jarvis (a primeira resposta demora, o modelo esta carregando)."
    Rodar 7 { & $Jarvis ask "Responda em português: quem é você?" }
}

# ---------------------------------------------------------------- 8. Palmas
if ($Etapa -le 8) {
    Passo 8 "Vou instalar o que o palmas.py precisa e rodar a calibracao do microfone."
    $palmas = Join-Path $Kit "palmas.py"
    if (-not (Test-Path $palmas)) { Falhar 8 "o arquivo palmas.py ainda nao esta nesta pasta. Cole o conteudo dele para o Claude e baixe o kit de novo." }
    $py = Join-Path $Src ".venv\Scripts\python.exe"
    if (-not (Test-Path $py)) { Falhar 8 "nao achei o Python do OpenJarvis em $py." }
    Rodar 8 { uv pip install --python $py -r (Join-Path $Kit "requirements-palmas.txt") }
    Write-Host "Agora: fique 5 segundos em silencio e depois bata palmas algumas vezes. Anote os numeros e mande para o Claude." -ForegroundColor Yellow
    Rodar 8 { & $py $palmas --calibrar }
}

# ---------------------------------------------------------------- 9. Interface
if ($Etapa -le 9) {
    Passo 9 "Vou conferir o Node.js (precisa ser 22 ou mais novo) e abrir a interface grafica com 'jarvis gui'."
    $nodeOk = $false
    if (Tem "node") {
        $v = (node --version)
        if ($v -match "^v(\d+)" -and [int]$Matches[1] -ge 22) { $nodeOk = $true; Write-Host "Node OK: $v" }
        else { Write-Host "Node antigo: $v" }
    }
    if (-not $nodeOk) {
        Rodar 9 { winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements }
        AtualizarPath
        $v = (node --version)
        if (-not ($v -match "^v(\d+)" -and [int]$Matches[1] -ge 22)) { Falhar 9 "o Node instalado e $v, mas precisa ser 22 ou mais novo." }
    }
    Write-Host "Abrindo a interface (deixe esta janela aberta; Ctrl+C fecha)..." -ForegroundColor Green
    Rodar 9 { & $Jarvis gui }
}
