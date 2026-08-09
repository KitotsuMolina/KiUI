# Publicar una versión

El repositorio incluye `scripts/release.sh` para mantener sincronizados la versión
de Cargo, el commit de release y el tag que activa el workflow de GitHub Actions.

Comprueba primero la siguiente versión sin modificar archivos:

```bash
scripts/release.sh --patch --dry-run
```

Publica una versión incrementando `patch`, `minor` o `major`:

```bash
scripts/release.sh --patch --push
```

`--path` se acepta como alias de `--patch`. El repositorio debe estar limpio. El
script ejecuta `cargo check --workspace` y `cargo test --workspace --locked`, crea
`chore(release): vX.Y.Z`, añade un tag anotado y, con `--push`, envía la rama y el
tag atómicamente. El tag `vX.Y.Z` activa `.github/workflows/release.yml`.

Solo en una emergencia puede usarse `--skip-tests`; no se recomienda para una
publicación normal.
