# -*- coding: utf-8 -*-
"""
Normaliza frecuencias dominantes usando la distribución real
de TODOS tus audios y detecta outliers automáticamente.
"""

import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, filtfilt, welch

CARPETA = r"D:\mosquitos"
EXTENSIONES = (".wav",)

LOWCUT = 100
HIGHCUT = 1100


# ======================
# FILTRO
# ======================
def filtrar_audio(data, fs):
    b, a = butter(4, [LOWCUT/(fs/2), HIGHCUT/(fs/2)], btype='band')
    return filtfilt(b, a, data)


# ======================
# FRECUENCIA DOMINANTE
# ======================
def frecuencia_dominante(ruta_audio):
    try:
        fs, data = wavfile.read(ruta_audio)

        if len(data.shape) > 1:
            data = data[:, 0]

        data = data.astype(np.float32)
        data = data - np.mean(data)

        if np.max(np.abs(data)) < 1e-6:
            return None

        data = data / np.max(np.abs(data))

        data_filtrado = filtrar_audio(data, fs)

        f, Pxx = welch(
            data_filtrado,
            fs,
            nperseg=min(4096, len(data_filtrado))
        )

        mask = (f >= LOWCUT) & (f <= HIGHCUT)

        if np.sum(mask) == 0:
            return None

        f = f[mask]
        Pxx = Pxx[mask]

        return f[np.argmax(Pxx)]

    except:
        return None


# ======================
# RECOLECTAR FRECUENCIAS
# ======================
resultados = []

for archivo in os.listdir(CARPETA):

    if archivo.lower().endswith(EXTENSIONES):

        ruta = os.path.join(CARPETA, archivo)

        freq = frecuencia_dominante(ruta)

        if freq is not None:
            resultados.append((archivo, freq))


# ======================
# NORMALIZACIÓN ROBUSTA
# ======================
frecuencias = np.array([x[1] for x in resultados])

mediana = np.median(frecuencias)

mad = np.median(np.abs(frecuencias - mediana))

# Aproximación robusta
limite_inferior = mediana - 2 * mad
limite_superior = mediana + 2 * mad


# ======================
# RESULTADOS
# ======================
print("Frecuencia central (mediana):", round(mediana, 2), "Hz")
print("Rango normal automático:",
      round(limite_inferior, 2),
      "Hz a",
      round(limite_superior, 2),
      "Hz\n")

print("AUDIOS ANÓMALOS:\n")

contador = 0

for archivo, freq in resultados:

    if freq < limite_inferior or freq > limite_superior:

        print(f"{archivo} --> {freq:.2f} Hz")
        contador += 1


print(f"\nTOTAL ANÓMALOS: {contador}")