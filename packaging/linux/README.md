# Integracion Linux de KiUI

`dev.kitotsu.kiui.desktop.in` es una plantilla distribuida, no el archivo que se
instala directamente.

GekkoApp materializa:

```text
$XDG_DATA_HOME/applications/dev.kitotsu.kiui.desktop
```

Tokens admitidos:

- `@EXECUTABLE@`: ruta absoluta y escapada al entrypoint activo de `kiui`;
- `@APPLICATION_ID@`: `dev.kitotsu.kiui`.

El empaquetador genera las variantes de icono declaradas en el manifiesto a partir
de `qml/assets/kiui-logo.png`. GekkoApp las instala bajo el tema `hicolor` y registra
el archivo `.desktop`, los iconos y sus hashes en su estado de instalacion.
