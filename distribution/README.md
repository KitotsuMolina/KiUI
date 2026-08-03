# Distribucion de KiUI

Los tags semanticos `v*.*.*` generan un release Linux para
`x86_64-unknown-linux-gnu` con:

- binario `kiui`;
- plantilla freedesktop;
- iconos `hicolor`;
- licencias del proyecto y de Material Symbols;
- manifiesto de instalacion v1, SBOM SPDX y checksums.

GekkoApp instala el artefacto, resuelve `runtime.qt6`, materializa el archivo
`.desktop` y habilita unicamente los modulos detectados por KiUI.
