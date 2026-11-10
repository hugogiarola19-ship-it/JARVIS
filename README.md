# Meu Jarvis

Assistente de IA que roda 100% no meu computador (Windows), escuta e responde em português e
acorda com duas palmas. Feito com o [OpenJarvis](https://github.com/open-jarvis/OpenJarvis).

## Como instalar

1. Baixe esta pasta para o computador (botão **Code > Download ZIP** no GitHub, e descompacte;
   ou `git clone`).
2. Abra o **PowerShell** dentro da pasta (Shift + botão direito na pasta > "Abrir janela do
   PowerShell aqui").
3. Rode:

```powershell
powershell -ExecutionPolicy Bypass -File .\instalar.ps1
```

O script anda em 9 etapas. Antes de cada uma ele diz em uma frase o que vai fazer e espera você
apertar Enter. Se algo der errado ele **para**, mostra o erro e diz como retomar
(`-Etapa N`). Copie o erro e mande para o Claude.

| Etapa | O que faz |
|---|---|
| 1 | Mostra sistema, RAM e placa de vídeo e sugere o cérebro: `gemma4:e4b` (16 GB de RAM ou mais) ou `gemma4:e2b` |
| 2 | Confere Python 3.10–3.13, git e MSVC Build Tools; roda o instalador oficial `install.ps1` (traz uv e Ollama) |
| 3 | `ollama pull <modelo>` e `jarvis config set intelligence.default_model <modelo>` |
| 4 | Instala os extras `speech` e `voice`; `speech.language pt`, `speech.model small` |
| 5 | Instala o espeak-ng; `speech.tts_backend kokoro`, `speech.voice_id pf_dora` |
| 6 | `jarvis doctor` — repita até ficar limpo |
| 7 | `jarvis ask "Responda em português: quem é você?"` |
| 8 | Instala as dependências do `palmas.py` e roda `palmas.py --calibrar` |
| 9 | Confere o Node.js 22+ e abre `jarvis gui` |

Reserve tempo e internet: são vários GB de download (Build Tools, modelo, vozes).

## Escolhendo o LIMIAR das palmas

A calibração (`.\palmas.cmd --calibrar`) só mostra sons com pico acima de 0,05, numa linha como
`pico 0.62  ruído 0.004`; em silêncio não aparece nada. Faça assim:

1. Bata palmas umas 10 vezes, do lugar onde você costuma ficar, e anote o **menor** pico delas.
2. Fale alto, digite, arraste a cadeira, e anote o **maior** pico desses barulhos.
3. O `LIMIAR` (linha `LIMIAR = 0.30` do `palmas.py`) fica entre os dois: comece com uns 70% da
   palma mais fraca.

Dispara sozinho com barulho? Aumente. Não percebe as palmas? Diminua. Se as palmas dão pico
abaixo de 0,2, aumente antes o volume do microfone no Windows.

## Onde fica cada coisa

- OpenJarvis: `%LOCALAPPDATA%\OpenJarvis` (código em `src`, comando em `bin\jarvis.cmd`)
- Configuração: `%USERPROFILE%\.openjarvis\config.toml`
- Modelos do Ollama: `%USERPROFILE%\.ollama`

## Dia a dia

```powershell
jarvis          # conversar pelo terminal
.\palmas.cmd    # ficar ouvindo: duas palmas acordam o Jarvis
jarvis gui      # interface gráfica no navegador
```

## Avisos

- Este kit foi escrito lendo o instalador e a documentação oficiais, mas **ainda não foi
  executado num Windows de verdade**; a primeira rodada é o teste.
- A documentação do OpenJarvis não descreve as chaves `speech.*`, a voz `pf_dora` nem os modelos
  `gemma4:*`. Se a etapa 3, 4 ou 5 reclamar de chave ou modelo desconhecido, pare e mande o erro.
- O `palmas.py` abre o Jarvis com `uv run jarvis chat --voice` dentro de
  `%LOCALAPPDATA%\OpenJarvis\src`. Esse modo de voz também não está na documentação que foi lida;
  se o Jarvis não reconhecer o comando, mande o erro.
- Se abrir um PowerShell novo e `jarvis` não for reconhecido, feche e abra a janela de novo
  (o PATH só atualiza em janelas novas).
