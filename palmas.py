# palmas.py: acorda o seu Jarvis com duas palmas.
#
# Fica ouvindo o microfone. Quando escuta duas palmas seguidas, fala
# "Online. Às suas ordens." e abre o Jarvis em modo de voz (jarvis chat --voice).
# Quando você sai do chat, ele volta a esperar as palmas.
#
# Instalar (no mesmo Python do OpenJarvis, ou em qualquer Python 3.10+):
#   pip install sounddevice numpy kokoro soundfile
# Rodar:
#   python palmas.py              # modo normal
#   python palmas.py --calibrar   # mostra o volume de cada som para ajustar o LIMIAR
#
# No Windows com o instalador nativo, o comando do Jarvis é "uv run jarvis" dentro de
# %LOCALAPPDATA%\OpenJarvis\src. Este arquivo já vem ajustado para isso (veja JARVIS_CMD
# e JARVIS_DIR abaixo); para trocar, defina as variáveis de ambiente de mesmo nome.
import os
import queue
import shlex
import subprocess
import sys
import time

import numpy as np

SR = 16000            # amostras por segundo do microfone
BLOCO = 512           # ~32 ms por leitura
LIMIAR = 0.30         # volume mínimo de uma palma (0 a 1). Ajuste com --calibrar
CONTRASTE = 6.0       # a palma precisa ser X vezes mais alta que o ruído da sala
JANELA = (0.12, 0.9)  # tempo entre a 1ª e a 2ª palma, em segundos
SURDO = 0.10          # ignora o eco da mesma palma por esse tempo
FRASE = 'Online. Às suas ordens.'
VOZ = os.environ.get('JARVIS_VOZ', 'pf_dora')  # voz em português do Kokoro

# Comando que abre o Jarvis e a pasta de onde ele roda.
if os.name == 'nt':  # Windows, instalador nativo do OpenJarvis
    _RAIZ = os.environ.get('OPENJARVIS_HOME') or os.path.join(os.environ.get('LOCALAPPDATA', ''), 'OpenJarvis')
    JARVIS_CMD = os.environ.get('JARVIS_CMD', 'uv run jarvis chat --voice')
    JARVIS_DIR = os.environ.get('JARVIS_DIR') or os.path.join(_RAIZ, 'src')
else:
    JARVIS_CMD = os.environ.get('JARVIS_CMD', 'jarvis chat --voice')
    JARVIS_DIR = os.environ.get('JARVIS_DIR') or None


class Detector:
    """Recebe o pico e a média de cada bloco e diz quando ouviu duas palmas."""

    def __init__(self, limiar=LIMIAR, contraste=CONTRASTE):
        self.limiar = limiar
        self.contraste = contraste
        self.ruido = 0.01      # média móvel do som ambiente
        self.ultimo = -10.0    # último som forte aceito
        self.primeira = None   # quando veio a 1ª palma

    def passo(self, pico, media, agora):
        forte = pico >= self.limiar and pico >= self.ruido * self.contraste
        if not forte:
            # só aprende o ruído com blocos que não são palma
            self.ruido = 0.98 * self.ruido + 0.02 * max(media, 1e-4)
            if self.primeira is not None and agora - self.primeira > JANELA[1]:
                self.primeira = None
            return False
        if agora - self.ultimo < SURDO:
            return False
        self.ultimo = agora
        if self.primeira is not None and JANELA[0] <= agora - self.primeira <= JANELA[1]:
            self.primeira = None
            return True
        self.primeira = agora
        return False


def falar(texto):
    """Fala com o Kokoro (local). Se não estiver instalado, só escreve na tela."""
    print(f'\n>>> {texto}\n')
    try:
        import sounddevice as sd
        from kokoro import KPipeline
        pipe = falar.pipe = getattr(falar, 'pipe', None) or KPipeline(lang_code='p')
        for _, _, audio in pipe(texto, voice=VOZ):
            audio = audio.numpy() if hasattr(audio, 'numpy') else np.asarray(audio)
            sd.play(audio, 24000)
            sd.wait()
    except Exception as erro:  # sem kokoro / sem espeak-ng: segue sem voz
        print(f'(voz indisponível: {erro})')


def abrir_jarvis():
    cmd = shlex.split(JARVIS_CMD, posix=os.name != 'nt')
    pasta = JARVIS_DIR
    print('Abrindo:', ' '.join(cmd))
    subprocess.run(cmd, cwd=pasta, shell=os.name == 'nt')


def ouvir(calibrar=False):
    import sounddevice as sd
    fila = queue.Queue()

    def callback(dados, frames, tempo, status):
        x = np.abs(dados[:, 0])
        fila.put((float(x.max()), float(x.mean())))

    det = Detector()
    print('Esperando duas palmas… (Ctrl+C para sair)')
    while True:
        with sd.InputStream(samplerate=SR, blocksize=BLOCO, channels=1, callback=callback):
            inicio = time.monotonic()
            n = 0
            while True:
                pico, media = fila.get()
                agora = inicio + n * BLOCO / SR
                n += 1
                if calibrar:
                    if pico > 0.05:
                        print(f'pico {pico:.2f}  ruído {det.ruido:.3f}')
                    continue
                if det.passo(pico, media, agora):
                    break
        while not fila.empty():
            fila.get()
        falar(FRASE)
        abrir_jarvis()
        det = Detector()
        print('\nEsperando duas palmas de novo…')


if __name__ == '__main__':
    try:
        ouvir(calibrar='--calibrar' in sys.argv)
    except KeyboardInterrupt:
        print('\nAté logo.')
