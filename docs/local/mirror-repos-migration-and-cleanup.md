# Guía de Migración, Limpieza y Mantenimiento de Repositorios Espejo (Mirror Repos) — ARCHIVADA

> ⚠️ **SUPERADA (change US-36):** La sincronización por `git subtree push` hacia los 4 repos espejo (`hjagar/us-refinement`, `hjagar/req-discovery`, `hjagar/res-onboarding`, `hjagar/tc-generator`) fue **retirada por completo**. Los 4 workflows `.github/workflows/sync-*.yml` fueron eliminados. Ningún mirror se sincroniza más desde este monorepo. Motivo: intentar re-habilitar el sync contra `tc-generator` (el único mirror que llegó a hacerse público) expuso problemas de credenciales sin resolver, y ninguno de los 4 mirrors tenía de todos modos un camino de instalación funcional propio — la única fuente de instalación real siempre fue (o será) `hjagar-skills` mismo, vía el instalador global resuelto por tag `<skill>-v*` (change `US17-global-install-release-resolution`, Sección 7 de este doc). Los mirrors existentes **no fueron tocados** (no se archivaron, no cambió su visibilidad) — simplemente dejaron de recibir actualizaciones. El resto de este documento (Secciones 1-6) describe la infraestructura de sync retirada; se conserva como referencia histórica, no como procedimiento vigente. Solo la Sección 7 (estrategia de releases del monorepo) sigue aplicando.

> **Propósito original (ya no vigente):** Documentar los pasos exactos para configurar la sincronización por CI y mantener los repositorios espejo, archivar los que dejaron de tener función (`hjagar/us-refinement`, `hjagar/req-discovery`), y definir la estrategia de releases y distribución real del monorepo `hjagar-skills`.

---

## 📋 Tabla de Contenidos

1. [Configuración de Autenticación CI (`GH_PAT`)](#1-configuración-de-autenticación-ci-gh_pat)
2. [Limpieza de Elementos Repetidos y Legacy](#2-limpieza-de-elementos-repetidos-y-legacy)
3. [Ejecución y Verificación de Sincronización Inicial](#3-ejecución-y-verificación-de-sincronización-inicial)
4. [Aviso de Mirror Read-Only en los Repos Espejo](#4-aviso-de-mirror-read-only-en-los-repos-espejo)
5. [Gobernanza y Redirección de Contribuciones](#5-gobernanza-y-redirección-de-contribuciones)
6. [(Histórico) Archivado de Mirrors Públicos — plan original, no ejecutado tal cual](#6-histórico-archivado-de-mirrors-públicos--plan-original-no-ejecutado-tal-cual)
7. [Estrategia de Releases y Distribución (vigente)](#7-estrategia-de-releases-y-distribución-vigente)

**Nota de alcance:** Las secciones 1-5 describen infraestructura de sync **retirada** (ver aviso al inicio del documento) — ninguno de los 4 mirrors se sincroniza más. Se conservan como referencia histórica.

---

## 1. Configuración de Autenticación CI (`GH_PAT`)

Para que los workflows de GitHub Actions (`.github/workflows/sync-res-onboarding.yml`, `sync-tc-generator.yml`) en `hjagar-skills` puedan empujar cambios mediante `git subtree push` hacia `res-onboarding` y `tc-generator`:

1. Ir a GitHub: **Settings -> Developer Settings -> Personal Access Tokens -> Tokens (classic)**.
2. Generar un nuevo token con scope **`repo`** (o permiso `contents: write`).
3. En el monorepo `hjagar-skills`, ir a **Settings -> Secrets and variables -> Actions -> New repository secret**.
4. Crear el secret con el nombre **`GH_PAT`** (o `SYNC_PAT`) y pegar el valor del token.

Los 4 workflows `sync-*.yml` fueron eliminados por completo (US-36) — ninguno necesita auth porque ninguno corre más.

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

## 6. (Histórico) Archivado de Mirrors Públicos — plan original, no ejecutado tal cual

Esta sección describía un plan de archivar solo 2 de los 4 mirrors (`hjagar/us-refinement`, `hjagar/req-discovery`) una vez cumplida una precondición (repo público + release + install.sh funcionando). Ese plan quedó **superado por US-36**: en vez de esperar la precondición y archivar solo 2, se cortó el sync de los 4 de una — ninguno tenía de todos modos un install path funcional propio (`tc-generator` llegó a hacerse público para probar, pero el sync seguía fallando por credenciales sin resolver).

**Estado actual:** los 4 mirrors (`us-refinement`, `req-discovery`, `res-onboarding`, `tc-generator`) siguen existiendo con su visibilidad original, sin archivar — solo dejaron de recibir sync. Archivarlos (`gh repo archive <repo>`, reversible con `gh repo unarchive <repo>`) sigue siendo una opción futura, pero ya no es parte de este flujo de trabajo; queda a criterio del maintainer si/cuándo hacerlo, sin precondición bloqueante.

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
