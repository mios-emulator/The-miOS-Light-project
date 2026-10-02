# 🚀 The miOS Light Project

Un simulador de sistema operativo ultra fluido, ligero y de alto rendimiento diseñado para Android, construido desde cero utilizando el motor **LÖVE2D (Lua)**.

---

## ⚡ Rendimiento y Visuales

A diferencia de las versiones tradicionales basadas en el entorno Java de Android, **miOS Light** está pensado para exprimir al máximo el hardware con un consumo mínimo de recursos.

- **120 FPS Estables:** Tiempos de frame promedio de **~8.5ms**.
- **Consumo Mínimo de Memoria:** Apenas **~1.4 MB de RAM** en ejecución.
- **Efecto Liquid Glass:** Renderizado de transparencias y capas de cristal en tiempo real con aceleración por hardware.
- **Animaciones de Físicas:** Transiciones, aperturas y cierres de aplicaciones totalmente fluidas.

---

## 📱 Distribución e Instalación

Para garantizar la compatibilidad entre una amplia variedad de dispositivos y capas de personalización, el proyecto se distribuye en dos variantes:

1. **Standard APK (`Target SDK 9`):**  
   Pensado para un rendimiento óptimo en dispositivos antiguos y tablets con capas estrictas (ej. Amazon Fire OS).
2. **Fix APK (`Target SDK 17+`):**  
   Versión ajustada para permitir la instalación en sistemas Android modernos y ROMs con verificaciones de seguridad estrictas (Xiaomi, Honor, etc.).

---

## 📂 Estructura del Código

- **`main.lua`**: Bucle principal, gestión de eventos, pipeline de renderizado y motor visual.
- **`conf.lua`**: Configuración de ventana, gráficos y parámetros del motor LÖVE2D.
- **`miniapps.lua`**: Módulo con las mini aplicaciones integradas (Calculadora, juegos, utilidades).

---

## 📄 Licencia

Este proyecto está bajo la licencia **GNU General Public License v3.0 (GPL-3.0)**. Puedes consultar el archivo `LICENSE` para obtener más información.
