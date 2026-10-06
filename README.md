# 🚀 The miOS Light Project

Un simulador de sistema operativo ultra fluido, ligero y de alto rendimiento diseñado para Android, construido desde cero utilizando el motor **LÖVE2D (Lua)**.

---

## ⚡ Rendimiento y Visuales

A diferencia de las versiones tradicionales basadas en el entorno Java de Android, **miOS Light** está pensado para exprimir al máximo el hardware con un consumo mínimo de recursos.

- **120 FPS Estables / Unlock FPS:** Tiempos de frame promedio de **~8.5ms**.
- **Consumo Mínimo de Memoria:** Apenas **~1.4 MB de RAM** en ejecución.
- **Efecto Liquid Glass:** Renderizado de transparencias y capas de cristal en tiempo real con aceleración por hardware.
- **Animaciones de Físicas:** Transiciones, aperturas y cierres de aplicaciones totalmente fluidas.

---

## 📱 Distribución e Instalación

Para garantizar la compatibilidad entre una amplia variedad de dispositivos y maximizar el rendimiento según la tasa de refresco, el proyecto se distribuye en **4 variantes independientes**:

| Variante | Compatibilidad Android | Sincronización Vertical (VSync) | Caso de uso ideal |
| :--- | :--- | :--- | :--- |
| **Standard** | Android 6.0 – 9.0 | VSync Activado (`vsync = 1`) | Dispositivos antiguos / tablets (ej. Fire OS). Ahorro de batería y 60 FPS estables. |
| **Standard (Unlock FPS)** | Android 6.0 – 9.0 | VSync Desactivado (`vsync = 0`) | Rendimiento máximo sin límites en hardware legacy. |
| **Fix** | Android 9.0 – 17+ | VSync Activado (`vsync = 1`) | Sistemas modernos (Xiaomi, Honor, etc.) con verificaciones de SDK estrictas. |
| **Fix (Unlock FPS)** | Android 9.0 – 17+ | VSync Desactivado (`vsync = 0`) | Pantallas de alta tasa de refresco (90Hz, 120Hz, 144Hz) y pruebas de rendimiento. |

---

## 📂 Estructura del Código

- **`main.lua`**: Bucle principal, gestión de eventos, pipeline de renderizado y motor visual.
- **`conf.lua`**: Configuración de ventana, gráficos, VSync y parámetros del motor LÖVE2D.
- **`miniapps.lua`**: Módulo con las mini aplicaciones integradas (Calculadora, juegos, utilidades).

---

## 🖼️ Personalización y Archivos

Para cargar tus propios fondos de pantalla desde la app de Ajustes, coloca tus imágenes dentro de la carpeta local de tu almacenamiento:

```text
wallpapers/  --> Soporta formatos .png y .jpg
```

---

## 📄 Licencia

Este proyecto está bajo la licencia **GNU General Public License v3.0 (GPL-3.0)**. Puedes consultar el archivo `LICENSE` para obtener más información.
