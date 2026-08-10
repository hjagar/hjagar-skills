# Guía de Migración, Limpieza y Mantenimiento de Repositorios Espejo (Mirror Repos)

> **Propósito:** Documentar los pasos exactos para configurar la sincronización por CI y mantener los repositorios espejo que siguen activos (`hjagar/res-onboarding`, `hjagar/tc-generator`), archivar los que dejaron de tener función (`hjagar/us-refinement`, `hjagar/req-discovery`), y definir la estrategia de releases y distribución real del monorepo `hjagar-skills` (change `US17-global-install-release-resolution`).

> ⚠️ **ACTUALIZADO (change US17-global-install-release-resolution):** Este documento describía originalmente un plan de "limpiar y mantener" los 4 repos espejo, más una estrategia de release con un bundle separado `hjagar-skills-all.zip` y un flag `--all`. Ese plan quedó **reemplazado**. Motivo: una vez que el instalador global resuelve releases directo contra `hjagar/hjagar-skills` (monorepo, público) filtrando por prefijo de tag `<skill>-v*`, los mirrors dejan de tener la única función que justificaba mantenerlos (ser el target público de descarga). Ver Sección 6.

---

## 📋 Tabla de Contenidos

1. [Configuración de Autenticación CI (`GH_PAT`)](#1-configuración-de-autenticación-ci-gh_pat)
2. [Limpieza de Elementos Repetidos y Legacy](#2-limpieza-de-elementos-repetidos-y-legacy)
3. [Ejecución y Verificación de Sincronización Inicial](#3-ejecución-y-verificación-de-sincronización-inicial)
4. [Aviso de Mirror Read-Only en los Repos Espejo](#4-aviso-de-mirror-read-only-en-los-repos-espejo)
5. [Gobernanza y Redirección de Contribuciones](#5-gobernanza-y-redirección-de-contribuciones)
6. [Archivado de Mirrors Públicos (`us-refinement`, `req-discovery`)](#6-archivado-de-mirrors-públicos-us-refinement-req-discovery)
7. [Estrategia de Releases y Distribución (vigente)](#7-estrategia-de-releases-y-distribución-vigente)

**Nota de alcance:** Las secciones 1-5 aplican únicamente a los mirrors que **siguen activos**: `hjagar/res-onboarding` y `hjagar/tc-generator`. `hjagar/us-refinement` y `hjagar/req-discovery` no se limpian ni se mantienen — se archivan (Sección 6).

---

## 1. Configuración de Autenticación CI (`GH_PAT`)

Para que los workflows de GitHub Actions (`.github/workflows/sync-res-onboarding.yml`, `sync-tc-generator.yml`) en `hjagar-skills` puedan empujar cambios mediante `git subtree push` hacia `res-onboarding` y `tc-generator`:

1. Ir a GitHub: **Settings -> Developer Settings -> Personal Access Tokens -> Tokens (classic)**.
2. Generar un nuevo token con scope **`repo`** (o permiso `contents: write`).
3. En el monorepo `hjagar-skills`, ir a **Settings -> Secrets and variables -> Actions -> New repository secret**.
4. Crear el secret con el nombre **`GH_PAT`** (o `SYNC_PAT`) y pegar el valor del token.

`sync-us-refinement.yml` y `sync-req-discovery.yml` se eliminan como parte del archivado (Sección 6) — no necesitan auth porque dejan de correr.

---

## 2. Limpieza de Elementos Repetidos y Legacy

### ⚠️ Elementos Obsoletos en Repos Standalone Viejos
En la arquitectura anterior, cada repositorio individual mantenía copias duplicadas de:
- Scripts de instalación/desinstalación: `install.sh`, `install.ps1`, `uninstall.sh`, `uninstall.ps1`.
- Scripts de actualización: `update.sh`, `update.ps1`.
- Scripts de release: `Release-Repo.sh`, `Release-Repo.ps1`.
- Carpeta `lib/` (con copias redundantes de `skill-payload.*`).

### 🧹 Estrategia de Limpieza (aplica a `res-onboarding` y `tc-generator`)
1. **En el Monorepo (`hjagar-skills`):**
   - La lógica CLI vive **exclusivamente** en `cli/` (`cli/install.*`, `cli/update.*`, `cli/Release-Repo.*`, `cli/lib/*`).
   - Las carpetas `skills/<nombre>/` **solo** contienen el artefacto puro de la skill (`SKILL.md`, `scripts/`, `tests/`, `validation.json`, `assets/`, `references/`, `examples/`).
   - No debe existir ningún script duplicado de `install` o `Release-Repo` dentro de `skills/<nombre>/`.

2. **En los Repositorios Espejo (`hjagar/res-onboarding`, `hjagar/tc-generator`):**
   - La sincronización `git subtree push --prefix=skills/<nombre>` reemplaza automáticamente el contenido de la rama `main` del espejo con la estructura limpia de `skills/<nombre>/`.
   - **Acción:** Eliminar cualquier rama secundaria o legacy en los repos espejo (ej. ramas viejas `master`, `dev`, o feature branches obsoletas):
     ```bash
     git push origin --delete <nombre-rama-vieja>
     ```

---

## 3. Ejecución y Verificación de Sincronización Inicial

Para verificar que el proceso de limpieza y sincronización funciona correctamente (`res-onboarding`, `tc-generator`):

1. En `hjagar-skills`, ir a la pestaña **Actions**.
2. Seleccionar cada workflow activo (*Sync res-onboarding mirror*, *Sync tc-generator mirror*).
3. Hacer clic en **Run workflow**.
4. Inspeccionar la raíz de los repositorios espejo en GitHub. Deben contener **únicamente** la estructura limpia de la skill:
   ```text
   hjagar/<skill-name>/
   ├── SKILL.md
   ├── validation.json (si aplica)
   ├── scripts/        (si aplica)
   ├── tests/          (si aplica)
   ├── assets/         (si aplica)
   └── references/     (si aplica)
   ```

---

## 4. Aviso de Mirror Read-Only en los Repos Espejo

Para evitar que los usuarios modifiquen los repositorios espejo activos por error, agregar la siguiente nota en la parte superior del `README.md` de `res-onboarding` y `tc-generator`:

```markdown
> ⚠️ **Note:** This repository is an automated read-only mirror of [`skills/<skill-name>`](https://github.com/hjagar/hjagar-skills/tree/main/skills/<skill-name>) in the [`hjagar-skills`](https://github.com/hjagar/hjagar-skills) monorepo. All issues, PRs, and contributions should be submitted to the main monorepo.
```

---

## 5. Gobernanza y Redirección de Contribuciones

1. **Desactivar / Redirigir Issues y Pull Requests:**
   En `res-onboarding` y `tc-generator` (**Settings -> General**):
   - Desactivar la opción de **Issues** si el proyecto lo permite, o bien configurar un issue template redirigiendo a `hjagar/hjagar-skills/issues`.
2. **Flujo Único de Trabajo:**
   Cualquier bugfix, mejora o nueva skill se desarrolla y aprueba mediante PRs exclusivamente en `hjagar-skills`. El CI se encarga de propagar los cambios automáticamente.

---

## 6. Archivado de Mirrors Públicos (`us-refinement`, `req-discovery`)

Los únicos dos mirrors públicos reales (`hjagar/us-refinement`, `hjagar/req-discovery`) se **archivan**, no se limpian ni se mantienen. Su única función — ser el target de descarga del instalador global — la reemplaza directamente `hjagar/hjagar-skills` una vez público, resolviendo releases por prefijo de tag `<skill>-v*` (ver Sección 7 y el diseño de `US17-global-install-release-resolution`).

### Precondición (no saltear)

Antes de archivar nada, deben estar verificados:
1. `hjagar/hjagar-skills` pasado a público.
2. Al menos un release real `<skill>-v*` cortado por skill vía el `Release-Repo.sh`/`.ps1` actualizado.
3. `curl | bash install.sh` funcionando de punta a punta sin autenticación — tanto con `--skill <nombre>` como sin flags (instala todos).

Archivar los mirrors antes de esto deja a los usuarios sin ninguna fuente de instalación funcionando.

### Qué hace `gh repo archive`

Pasa el repo a solo-lectura (sin push, issues, PRs ni releases nuevos), pero todo lo existente sigue visible y funcionando: releases, tags, stars, forks, watchers, URLs, clone. **Es reversible** (`gh repo unarchive <repo>` o el botón "Unarchive this repository" en Settings) — no es un delete ni un rename, la URL no cambia.

### Pasos, en orden

1. Confirmar la precondición de arriba.
2. Eliminar los dos workflows de sync que ya no tienen destino válido (empujarían a un repo de solo-lectura):
   ```bash
   git rm .github/workflows/sync-us-refinement.yml .github/workflows/sync-req-discovery.yml
   ```
   Commit aparte, mecánico — revisable independiente de cualquier otro PR de código.
3. Archivar cada mirror (requiere permisos de admin sobre ese repo):
   ```bash
   gh repo archive hjagar/us-refinement
   gh repo archive hjagar/req-discovery
   ```
   `gh` pide confirmación por Enter en cada uno (o `--yes`/`-y` para scripting no interactivo).
4. Verificar:
   ```bash
   gh repo view hjagar/us-refinement --json isArchived,isPrivate
   gh repo view hjagar/req-discovery --json isArchived,isPrivate
   ```
   Ambos deben reportar `"isArchived": true`.
5. No hace falta nada más — stars, forks, releases existentes y URLs de clone siguen funcionando en modo lectura. Los releases de skills de ahora en adelante viven únicamente en `hjagar/hjagar-skills`.

### Para deshacer, si hiciera falta

```bash
gh repo unarchive hjagar/us-refinement
gh repo unarchive hjagar/req-discovery
```
Instantáneo y reversible en ambas direcciones, sin pérdida de datos.

---

## 7. Estrategia de Releases y Distribución (vigente)

> Reemplaza la estrategia anterior de esta sección (bundle separado `hjagar-skills-all.zip` + flag `--all`). Esa alternativa fue evaluada y descartada explícitamente durante el diseño de `US17-global-install-release-resolution`: agregaba una segunda fuente de verdad de versiones (¿qué significa "latest" para un bundle cuando cada skill versiona independiente?) sin necesidad real, cuando el mecanismo de resolución por tag ya alcanza.

### 🎯 Releases por Skill Individual (`<skill>-vX.Y.Z`)

- **Fuente única:** `hjagar/hjagar-skills` (el monorepo, público). No hay mirrors ni bundle separado.
- **Cuándo se genera:** cuando una skill específica recibe cambios o requiere un salto de versión.
- **Comando:**
  - Bash: `./cli/Release-Repo.sh patch --skill us-refinement`
  - PowerShell: `.\cli\Release-Repo.ps1 -ReleaseType minor -Skill req-discovery`
- **Artefacto generado:** git tag `<skill>-vX.Y.Z`, publicado contra `origin` (sin `--repo`), con el zip incluyendo `skills/<name>/**` + `cli/lib/skill-payload.{sh,ps1}` (layout completo, no plano — corrige el defecto donde el zip anterior omitía la lib de instalación).
- **Preflight de seguridad:** antes de tag/push, el script verifica que el repo resuelto por `gh` sea exactamente `hjagar/hjagar-skills`; aborta sin tag/push si no coincide (protege contra remotes mal configurados).

### 📦 Instalación de un skill puntual

```bash
install.sh --skill req-discovery
```

Resuelve el release cuyo tag matchea `req-discovery-v*` con el semver más alto, contra `hjagar/hjagar-skills` — vía `gh api` si está disponible, o `curl`/`wget` sin autenticación si no (el repo público permite el fallback).

### 📦 Instalación de todos los skills (sin flag, sin bundle nuevo)

```bash
install.sh
```

Sin `--skill`, el instalador **no** defaultea a un skill fijo ni descarga un bundle separado: descubre todos los skills que tienen al menos un release publicado (parseando los tags `<skill>-v*` de la propia lista de releases del monorepo, ya consultada para la resolución individual) e instala cada uno con su propio zip, en loop. Si no hay ningún release publicado, falla con error explícito — no instala nada silenciosamente.

`update.sh` sin `--skill` sigue el mismo espíritu pero mirando el filesystem local: actualiza cada skill que ya está instalado en `~/.hjagar/skills`, cada uno contra su propio último release.

### 📌 Razones Técnicas

1. **Version Pinning e Inmutabilidad:** cada skill versiona independiente; el tag-prefix ya lo resuelve sin bundle.
2. **Sin segunda fuente de verdad:** "qué skills existen" siempre se deriva de los tags reales publicados — no hay manifest separado que se desincronice.
3. **Sin auth nueva:** el repo público + fallback `curl`/`wget` mantiene la instalación funcionando sin requerir `gh auth`.
