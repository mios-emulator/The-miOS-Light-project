# 📱 miOS Light v1.1.0

Un entorno de escritorio móvil fluido, minimalista e hiper-personalizable inspirado en sistemas operativos modernos, desarrollado enteramente en **Lua** con la librería **LÖVE (LOVE2D)**.

---

## ✨ Características Principales

### 🔮 Interfaz Liquid Glass & Renderizado
* **Efectos de vidrio líquido**: Blur y refracción realista en tiempo real mediante shaders GLSL (GLASS_SRC).
* **Soporte multitema**: Gradientes procedurales y orbes animados con 7 paletas personalizadas (Noche, Océano, Atardecer, Bosque, Rosa, Grafito, Aurora).
* **Fondo dinámico**: Soporte para fotos de fondo personalizadas mediante archivos .png o .jpg colocados en la carpeta wallpapers/.
* **Personalización total de íconos**: Cambio de tamaño, recorte por formas geométricas (Cuadrado, Normal, Suave, Círculo) mediante mask shaders, y visibilidad de etiquetas.

### 🏝️ Isla Dinámica (Dynamic Island)
* Interacción táctil interactiva con animaciones de resorte (spring physics).
* **Alertas y avisos contextuales**: Notificaciones de estado, conectividad y reproducción de medios.
* **Tarjeta de reproducción integrada**: Controles multimedia completos (Play/Pausa, Anterior, Siguiente) e interacción mediante arrastre (seeking) en la barra de progreso.
* **Acceso rápido**: Expandible desde la píldora para interactuar con los ajustes sin interrumpir la navegación.

### 🎛️ Centro de Control
* Panel deslizante con difuminado dinámico (background blur).
* Botones de alternancia directa: Modo Avión, Datos móviles, Wi-Fi, Bluetooth, No Molestar, Linterna, Rotación y Ahorro de batería.
* Controles táctiles precisos mediante sliders deslizables para la gestión de **Brillo** y **Volumen**.

### 📱 Mini-Apps y Utilidades Incluidas
* **Ajustes**: Panel completo con persistencia de datos local (settings.txt).
* **Reproductor de Música**: Reconocimiento de pistas locales, portadas de álbumes y medidor de ondas de audio (Equalizer bars).
* **Herramientas de Productividad y Entretenimiento**:
  * Notas y utilidades básicas.
  * Juego integrado 2048.
  * Accesos directos a aplicaciones web (WhatsApp, Google, TikTok, YouTube).

---

## 🛠️ Requisitos e Instalación

### Requisitos Previos
* **LÖVE 11.x (LOVE2D)** para Windows, Linux, macOS o Android.

### Ejecución
1. Clona el repositorio o descarga el código fuente

2. Ejecuta el proyecto en LÖVE2D:
   * **En PC (Windows/Linux):** Arrastra la carpeta del proyecto a la ejecutable love.exe o corre en consola: love .
   * **En Android:** Empaqueta en formato .love o abrí la carpeta directamente usando un lanzador compatible como Löve2droid.

---

## ⚙️ Estructura del Proyecto

* main.lua: Lógica principal del sistema, renderizado de la UI, animaciones y shaders.
* conf.lua: Configuración global de la ventana y parámetros de prueba en PC (relación de aspecto móvil 390x844).
* miniapps.lua: Módulo contenedor de miniaplicaciones y herramientas lógicas integradas.
* music.lua: Módulo de audio, gestión de listas de reproducción y extracción/dibujado de carátulas.
* assets/: Carpeta contenedora de imágenes e íconos (logo.png, icon_*.png).
* wallpapers/: Directorio donde el usuario puede colocar carpetas de imágenes personalizadas.

---

## 📜 Licencia

Desarrollado de forma abierta bajo licencia GPLv3.
