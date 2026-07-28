# Guía de Migración, Limpieza y Mantenimiento de Repositorios Espejo (Mirror Repos)

> **Propósito:** Documentar los pasos exactos para configurar la sincronización por CI, realizar la limpieza de elementos repetidos/legacy en los repositorios espejo individuales (`hjagar/req-discovery`, `hjagar/us-refinement`, `hjagar/res-onboarding`, `hjagar/tc-generator`), establecer el modelo de gobernanza y definir la estrategia de releases y distribución del monorepo `hjagar-skills`.

---

## 📋 Tabla de Contenidos

1. [Configuración de Autenticación CI (`GH_PAT`)](#1-configuración-de-autenticación-ci-gh_pat)
2. [Limpieza de Elementos Repetidos y Legacy](#2-limpieza-de-elementos-repetidos-y-legacy)
3. [Ejecución y Verificación de Sincronización Inicial](#3-ejecución-y-verificación-de-sincronización-inicial)
4. [Aviso de Mirror Read-Only en los Repos Espejo](#4-aviso-de-mirror-read-only-en-los-repos-espejo)
5. [Gobernanza y Redirección de Contribuciones](#5-gobernanza-y-redirección-de-contribuciones)
6. [Estrategia de Releases y Distribución (Próximos Pasos)](#6-estrategia-de-releases-y-distribución-próximos-pasos)

---

## 1. Configuración de Autenticación CI (`GH_PAT`)

Para que los workflows de GitHub Actions (`.github/workflows/sync-*.yml`) en `hjagar-skills` puedan empujar cambios mediante `git subtree push` hacia los repositorios individuales espejo:

1. Ir a GitHub: **Settings -> Developer Settings -> Personal Access Tokens -> Tokens (classic)**.
2. Generar un nuevo token con scope **`repo`** (o permiso `contents: write`).
3. En el monorepo `hjagar-skills`, ir a **Settings -> Secrets and variables -> Actions -> New repository secret**.
4. Crear el secret con el nombre **`GH_PAT`** (o `SYNC_PAT`) y pegar el valor del token.

---

## 2. Limpieza de Elementos Repetidos y Legacy

### ⚠️ Elementos Obsoletos en Repos Standalone Viejos
En la arquitectura anterior, cada repositorio individual mantenía copias duplicadas de:
- Scripts de instalación/desinstalación: `install.sh`, `install.ps1`, `uninstall.sh`, `uninstall.ps1`.
- Scripts de actualización: `update.sh`, `update.ps1`.
- Scripts de release: `Release-Repo.sh`, `Release-Repo.ps1`.
- Carpeta `lib/` (con copias redundantes de `skill-payload.*`).

### 🧹 Estrategia de Limpieza
1. **En el Monorepo (`hjagar-skills`):**
   - La lógica CLI vive **exclusivamente** en `cli/` (`cli/install.*`, `cli/update.*`, `cli/Release-Repo.*`, `cli/lib/*`).
   - Las carpetas `skills/<nombre>/` **solo** contienen el artefacto puro de la skill (`SKILL.md`, `scripts/`, `tests/`, `validation.json`, `assets/`, `references/`, `examples/`).
   - No debe existir ningún script duplicado de `install` o `Release-Repo` dentro de `skills/<nombre>/`.

2. **En los Repositorios Espejo (`hjagar/<nombre>`):**
   - La sincronización `git subtree push --prefix=skills/<nombre>` reemplaza automáticamente el contenido de la rama `main` del espejo con la estructura limpia de `skills/<nombre>/`.
   - **Acción:** Eliminar cualquier rama secundarias o legacy en los repos espejo (ej. ramas viejas `master`, `dev`, o feature branches obsoletas):
     ```bash
     git push origin --delete <nombre-rama-vieja>
     ```

---

## 3. Ejecución y Verificación de Sincronización Inicial

Para verificar que el proceso de limpieza y sincronización funciona correctamente:

1. En `hjagar-skills`, ir a la pestaña **Actions**.
2. Seleccionar cada workflow (*Sync req-discovery mirror*, *Sync us-refinement mirror*, etc.).
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

Para evitar que los usuarios modifiquen los repositorios espejo por error, agregar la siguiente nota en la parte superior del `README.md` de cada repo espejo:

```markdown
> ⚠️ **Note:** This repository is an automated read-only mirror of [`skills/<skill-name>`](https://github.com/hjagar/hjagar-skills/tree/main/skills/<skill-name>) in the [`hjagar-skills`](https://github.com/hjagar/hjagar-skills) monorepo. All issues, PRs, and contributions should be submitted to the main monorepo.
```

---

## 5. Gobernanza y Redirección de Contribuciones

1. **Desactivar / Redirigir Issues y Pull Requests:**
   En cada repositorio espejo (**Settings -> General**):
   - Desactivar la opción de **Issues** si el proyecto lo permite, o bien configurar un issue template redirigiendo a `hjagar/hjagar-skills/issues`.
2. **Flujo Único de Trabajo:**
   Cualquier bugfix, mejora o nueva skill se desarrolla y aprueba mediante PRs exclusivamente en `hjagar-skills`. El CI se encarga de propagar los cambios automáticamente.

---

## 6. Estrategia de Releases y Distribución (Próximos Pasos)

Dado que las skills se pueden instalar **de forma individual (`--skill <nombre>`)** o **todas juntas (`--all`)**, se establece una **Estrategia Doble de Releases**:

### 🎯 1. Releases por Skill Individual (`<skill>-vX.Y.Z`)
* **Cuándo se genera:** Cuando una skill específica recibe cambios o correcciones y requiere un salto de versión independiente.
* **Comando:** 
  - Bash: `./cli/Release-Repo.sh patch --skill us-refinement`
  - PowerShell: `.\cli\Release-Repo.ps1 -ReleaseType minor -Skill req-discovery`
* **Artefacto generado:** Git tag `<skill>-vX.Y.Z` y archivo `build/<skill>.zip`.
* **Casos de uso:** Consumidores que solo instalan o actualizan una skill particular (`install.sh --skill us-refinement`).

### 📦 2. Release Bundle del Monorepo (`vX.Y.Z` / `hjagar-skills-all.zip`)
* **Cuándo se genera:** Cuando se realiza un release global del monorepo que agrupa la colección completa de skills probadas en conjunto.
* **Artefacto generado:** Tag global `vX.Y.Z` (ej: `v1.0.0`) y asset `hjagar-skills-all.zip` conteniendo `skills/*`.
* **Casos de uso:** Consumidores que instalan la suite completa mediante `install.sh --all` o `install.ps1 -All`. El instalador descarga `hjagar-skills-all.zip` en una única petición atómica y despliega todas las skills en 1 segundo.

### 📌 Razones Técnicas para Mantener Releases
1. **Version Pinning e Inmutabilidad:** Evita que cambios directos en `main` rompan setups de usuarios en producción.
2. **Optimización de Ancho de Banda y Rendimiento:** Evita realizar *N* descargas por separado al instalar la suite completa.
3. **Entornos Corporativos:** Facilita la descarga en entornos con proxies restringidos que bloquean consultas arbitrarias a `raw.githubusercontent.com`.
