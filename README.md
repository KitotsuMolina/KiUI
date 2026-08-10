# KiUI

Proyecto visual principal del ecosistema, definido en
`docs/ADR-004-FRONTEND_UNIFICADO.md`.

## Superficies previstas

- `app/`: centro de control modular.
- `picker/`: selector rapido de contenido estatico y live.
- `shared/`: sistema visual, cliente de envelopes, modelos de presentacion,
  accesibilidad y geometria hexagonal.

## Limites

KiUI consume exclusivamente:

```text
kitowall --contract-v1
kilivepaper --contract-v1
kisddm --contract-v1
kitsune --contract-v1
```

Cada comando se ejecutara con argumentos separados, timeout y validacion estricta del
envelope. La UI no importa backends, no ejecuta herramientas del escritorio, no
controla RenderCore y no instala dependencias.

## Tecnologia

- Rust 2021;
- CXX-Qt 0.9;
- Qt 6.11;
- Qt Quick/QML.
- Material Symbols Rounded, incluido como subconjunto local.

La decision esta registrada en `docs/ADR-005-STACK_KIUI.md`.

## Identidad e instalacion grafica

El ID freedesktop y Wayland es `dev.kitotsu.kiui`. Debe coincidir entre Qt, la
plantilla `packaging/linux/dev.kitotsu.kiui.desktop.in` y el nombre de los iconos.
El release distribuye la plantilla; GekkoApp resuelve la ruta absoluta del
entrypoint y materializa el `.desktop` bajo `XDG_DATA_HOME`.

Las licencias de dependencias visuales distribuidas con KiUI se encuentran en
`THIRD_PARTY_LICENSES/`.

## Desarrollo

Requisitos:

```text
Rust estable
Qt >= 6.4
Qt Quick Controls 2
compilador C++
```

Comandos:

```bash
cargo test
cargo clippy --all-targets -- -D warnings
cargo run
cargo run -- --lc
```

`cargo run` y los builds debug resuelven Kitowall y Kitsune Compositor por defecto
desde los directorios `target/debug` o `target/release` de los proyectos hermanos.
`--lc` permite hacerlo explicito o forzarlo en un build release. Kitsune y
Kilivepaper se incorporaran automaticamente cuando existan sus binarios locales.
Un build release sin la flag detecta los modulos instalados mediante `PATH` o las
variables `KIUI_KITOWALL_BIN`, `KIUI_KILIVEPAPER_BIN` y `KIUI_KITSUNE_BIN`.
Kitsune Compositor es infraestructura obligatoria y se puede resolver mediante
`KIUI_COMPOSITOR_BIN`.

KiUI solo muestra las fuentes, filtros, descargas y secciones de configuracion de
los modulos detectados. Para probar cada composicion en modo local se puede iniciar
con `KIUI_DISABLE_KITOWALL=1` o `KIUI_DISABLE_KILIVEPAPER=1`.

En una sesion Wayland, el modo local usa por defecto el backend software de Qt
Quick para evitar fallos EGL durante el desarrollo. Se puede probar otro backend
definiendo explicitamente `QT_QUICK_BACKEND` o `QSG_RHI_BACKEND` antes de iniciar
KiUI. Los builds instalados conservan la seleccion grafica automatica de Qt.

## Estado

El MVP nativo incluye:

- shell modular;
- fuentes y filtros;
- panal hexagonal navegable;
- panel de detalle;
- dock de rotacion;
- fixtures estaticos/live;
- validacion Rust del envelope v1 y manifiesto de instalacion;
- cliente real del CLI Rust de Kitowall;
- modulo de configuracion con secciones General y Packs;
- lectura y guardado de modo, intervalo y transicion;
- CRUD de los seis providers de packs;
- multiselect de categorias/pureza y selector compatible de relacion/resolucion
  para Wallhaven;
- selector visual de la paleta de colores admitida por Wallhaven;
- jobs de refresh e hidratacion con ID, progreso, error y cancelacion;
- catalogo real paginado de Kitowall con previews dentro del panal y el panel
  de detalle;
- contadores reales de catalogo, provider, tipo, favoritos e historial.
- selector de outputs reales obtenido mediante `kitowall outputs`;
- aplicacion del wallpaper seleccionado por output mediante `wallpaper apply`;
- aplicacion del mismo wallpaper en todos los outputs mediante `wallpaper apply-batch`.
- seccion de estado para las cuatro automatizaciones estaticas y sus artefactos,
  consumida mediante `kitowall service status`.
- instalacion y reparacion confirmada de las automatizaciones desde Status mediante
  `kitowall service apply`, `service enable` y `service restart`, seguida de una
  reconciliacion del estado.
- componente `KiActionButton` para acciones secundarias, primarias y peligrosas,
  evitando que Qt Fusion aparezca en controles o dialogos de configuracion.
- selector de pack y filtros acumulativos por provider, tipo, favoritos, recientes,
  busqueda, color y resolucion minima.
- sincronizacion del dashboard mediante `dashboard snapshot`: watcher local con
  debounce, refresco inmediato de jobs/catalogo, cola mientras el bridge esta
  ocupado y reconciliacion forzada cada 30 segundos;
- contador y filtro de wallpapers descargados basado en `facets.hydrated`, sin
  inferir el estado desde QML.

Backend, seleccion, cache y pool ya se muestran cuando el contrato los devuelve,
pero permanecen en solo lectura hasta que el CLI publique mutaciones tipadas para
esos campos. KiUI no edita directamente el JSON de configuracion.

La deteccion de outputs requiere que KiUI herede la sesion grafica del usuario. Una
ejecucion desde una terminal aislada, un contenedor o una sesion sin los sockets del
compositor puede mostrar `Sin monitores` aunque el equipo tenga pantallas conectadas.
La barra inferior permite activar o desactivar la sincronizacion automatica de
colores para el monitor seleccionado. El control consulta
`appearance policy show` al iniciar y usa `appearance policy enable --confirm`
o `appearance policy disable`; KiUI no escribe directamente la configuracion
del compositor.

Cuando la politica esta activa, KiUI consume `appearance current` y deriva sus
tokens visuales de `accent_mid`, `accent_light`, `accent_dark` y `foreground`.
El archivo de estado del compositor se observa mediante eventos de filesystem,
por lo que una rotacion actualiza el tema sin sondeo continuo ni recarga del
catalogo. Los colores semanticos de exito, advertencia y error no se sustituyen
por la paleta del wallpaper.
