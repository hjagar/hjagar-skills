# hjagar-skills

> **Monorepo of agentic engineering skills with multi-agent CLI distribution.**

---

## 🌐 Table of Contents / Tabla de Contenidos

- [English Documentation](#english)
  - [Included Skills](#included-skills)
  - [Supported AI Agents](#supported-ai-agents)
  - [Installation & Usage](#installation--usage)
  - [Monorepo Architecture](#monorepo-architecture)
  - [Release Management](#release-management)
  - [License](#license)
- [Documentación en Español](#español)
  - [Skills Incluidas](#skills-incluidas)
  - [Agentes de IA Soportados](#agentes-de-ia-soportados)
  - [Instalación y Uso](#instalación-y-uso)
  - [Arquitectura Monorepo](#arquitectura-monorepo)
  - [Gestión de Releases](#gestión-de-releases)
  - [Licencia](#licencia)

---

<a name="english"></a>
# English Documentation

Welcome to `hjagar-skills`, the central monorepo for production-grade agentic engineering skills. This repository contains AI skills for requirement discovery, story refinement, developer onboarding, and QA test case generation, alongside CLI tooling to install, update, uninstall, and release skills across multiple AI coding assistants.

---

## 🚀 Included Skills

| Skill Name | Version | Description |
| :--- | :--- | :--- |
| **`req-discovery`** | [![req-discovery](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=req-discovery-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=req-discovery) | Extracts structured requirement candidates and user stories from raw conversation transcripts or meeting notes. |
| **`us-refinement`** | [![us-refinement](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=us-refinement-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=us-refinement) | Refines raw user stories into INVEST-compliant specifications with Gherkin (`Given/When/Then`) acceptance criteria. |
| **`res-onboarding`** | [![res-onboarding](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=res-onboarding-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=res-onboarding) | Onboards developers (junior/senior) into codebases with custom architecture guides, stack overviews, and setup instructions. |
| **`tc-generator`** | [![tc-generator](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=tc-generator-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=tc-generator) | Generates unit test guidance and QA manual test checklists covering happy paths, edge cases, and failure modes. |
| **`memsync`** | [![memsync](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=memsync-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=memsync) | Saves the session summary to Engram, syncs it to `.engram/`, and commits+pushes only the resulting chunk to the current branch. |
| **`memload`** | [![memload](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=memload-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=memload) | Imports pending Engram memory chunks from `.engram/` into the local DB and reports what was imported. |
| **`commit-push`** | [![commit-push](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=commit-push-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=commit-push) | Stages, commits (conventional format), and pushes any pending working-tree changes, reusing memsync's safety guardrails for any repo. |

> Each skill is versioned and released independently — a change to one skill does not bump the others. The tag prefix (`<skill>-vX.Y.Z`) is the source of truth; see [Release Management](#release-management).

---

## 🤖 Supported AI Agents

The installer automatically detects and deploys skills to all configured agent environments on your system:

- **Google Gemini CLI / Antigravity (`~/.gemini/skills/`)**
- **Claude Code (`~/.claude/skills/` & `~/.claude-*/skills/`)**
- **Cursor (`~/.cursor/skills/`)**
- **GitHub Copilot (`~/.copilot/skills/`)**
- **Kiro AI (`~/.kiro/steering/`)**
- **OpenCode (`~/.config/opencode/skills/`)**
- **Generic Agent Directory (`~/.agents/skills/`)**

---

## 💻 Installation & Usage

### 1. Installation

Install a specific skill or all available skills across your AI agent environments:

#### **Linux / macOS (Bash)**
```bash
# Install a specific skill (e.g., us-refinement)
curl -fsSL https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/install.sh | bash -s -- --skill us-refinement

# Install all skills in the monorepo (omitting --skill installs every skill with a published release)
curl -fsSL https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/install.sh | bash -s --
```

#### **Windows (PowerShell)**
```powershell
# Install a specific skill
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/install.ps1))) -Skill us-refinement

# Install all skills (omitting -Skill installs every skill with a published release)
irm https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/install.ps1 | iex
```

### 2. Updating Skills

Keep installed skills synchronized with the latest releases:

#### **Bash**
```bash
./cli/update.sh --skill us-refinement

# Omitting --skill updates every skill already installed locally (update.sh has no --all flag)
./cli/update.sh
```

#### **PowerShell**
```powershell
.\cli\update.ps1 -Skill us-refinement

# Omitting -Skill updates every skill already installed locally (update.ps1 has no -All flag)
.\cli\update.ps1
```

### 3. Uninstallation

Uninstall a specific skill or all skills from AI agent environments and central storage:

#### **Linux / macOS (Bash)**
```bash
# Remote 1-liner execution
curl -fsSL https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/uninstall.sh | bash -s -- --skill us-refinement
curl -fsSL https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/uninstall.sh | bash -s -- --all

# Or run locally from clone / central storage (~/.hjagar/skills/)
./cli/uninstall.sh --skill us-refinement
./cli/uninstall.sh --all
```

#### **Windows (PowerShell)**
```powershell
# Remote 1-liner execution
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/uninstall.ps1))) -Skill us-refinement
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/uninstall.ps1))) -All

# Or run locally from clone / central storage (~/.hjagar/skills/)
.\cli\uninstall.ps1 -Skill us-refinement
.\cli\uninstall.ps1 -All
```

---

## 🏗️ Monorepo Architecture

This monorepo follows a clean separation between **development/maintenance** and **distribution/consumption**:

- **Single Source of Truth**: All source code, quality gates, and CLI tooling live in `hjagar-skills`.

---

## 📦 Release Management

To quality-gate, version-bump, package, and create a GitHub release for a specific skill:

#### **Bash**
```bash
./cli/Release-Repo.sh patch --skill us-refinement
```

#### **PowerShell**
```powershell
.\cli\Release-Repo.ps1 -ReleaseType minor -Skill req-discovery
```

1. Runs quality gate validators (`validation.json` & fixtures) or graceful non-blocking warnings for doc-only skills.
2. Bumps `metadata.version` in `skills/<skill>/SKILL.md`.
3. Packages `build/<skill>.zip`.
4. Creates Git tag `<skill>-vX.Y.Z` and publishes GitHub release via `gh`.

---

<a name="español"></a>
# Documentación en Español

Bienvenido a `hjagar-skills`, el monorepositorio centralizado de skills de ingeniería para agentes de inteligencia artificial. Este repositorio contiene skills para descubrimiento de requerimientos, refinamiento de historias de usuario, onboarding de desarrolladores y generación de casos de prueba QA, junto con herramientas CLI para instalar, actualizar, desinstalar y liberar releases en múltiples asistentes de código.

---

## 🚀 Skills Incluidas

| Nombre de Skill | Versión | Descripción |
| :--- | :--- | :--- |
| **`req-discovery`** | [![req-discovery](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=req-discovery-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=req-discovery) | Extrae requerimientos candidatos e historias de usuario desde transcripciones de reuniones o notas brutas. |
| **`us-refinement`** | [![us-refinement](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=us-refinement-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=us-refinement) | Refina historias de usuario a especificaciones bajo el criterio INVEST con criterios de aceptación Gherkin (`Dado/Cuando/Entonces`). |
| **`res-onboarding`** | [![res-onboarding](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=res-onboarding-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=res-onboarding) | Realiza el onboarding de desarrolladores (junior/senior) en codebases con guías de arquitectura, tecnologías y configuración. |
| **`tc-generator`** | [![tc-generator](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=tc-generator-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=tc-generator) | Genera guías de tests unitarios y checklists manuales de QA cubriendo camino feliz, casos de borde y errores. |
| **`memsync`** | [![memsync](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=memsync-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=memsync) | Guarda el resumen de la sesión en Engram, lo sincroniza a `.engram/`, y commitea+sube solo el chunk resultante a la branch actual. |
| **`memload`** | [![memload](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=memload-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=memload) | Importa los chunks de memoria de Engram pendientes desde `.engram/` a la base local y reporta qué se importó. |
| **`commit-push`** | [![commit-push](https://img.shields.io/github/v/release/hjagar/hjagar-skills?filter=commit-push-v*&label=&color=blue)](https://github.com/hjagar/hjagar-skills/releases?q=commit-push) | Agrega al stage, commitea (formato convencional) y sube los cambios pendientes, reutilizando las guardas de seguridad de memsync. |

> Cada skill se versiona y se libera de forma independiente — un cambio en una skill no incrementa la versión de las demás. El prefijo del tag (`<skill>-vX.Y.Z`) es la fuente de verdad; ver [Gestión de Releases](#gestión-de-releases).

---

## 🤖 Agentes de IA Soportados

El instalador detecta y despliega automáticamente las skills en todos los entornos de agentes configurados en el sistema:

- **Google Gemini CLI / Antigravity (`~/.gemini/skills/`)**
- **Claude Code (`~/.claude/skills/` y `~/.claude-*/skills/`)**
- **Cursor (`~/.cursor/skills/`)**
- **GitHub Copilot (`~/.copilot/skills/`)**
- **Kiro AI (`~/.kiro/steering/`)**
- **OpenCode (`~/.config/opencode/skills/`)**
- **Directorio de Agentes Genérico (`~/.agents/skills/`)**

---

## 💻 Instalación y Uso

### 1. Instalación

Instalá una skill específica o todas las disponibles en tu sistema:

#### **Linux / macOS (Bash)**
```bash
# Instalar una skill específica (ej. us-refinement)
curl -fsSL https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/install.sh | bash -s -- --skill us-refinement

# Instalar todas las skills del monorepo (omitiendo --skill se instalan todas las que tengan release publicado)
curl -fsSL https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/install.sh | bash -s --
```

#### **Windows (PowerShell)**
```powershell
# Instalar una skill específica
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/install.ps1))) -Skill us-refinement

# Instalar todas las skills (omitiendo -Skill se instalan todas las que tengan release publicado)
irm https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/install.ps1 | iex
```

### 2. Actualización

Mantené las skills instaladas al día con las últimas versiones:

#### **Bash**
```bash
./cli/update.sh --skill us-refinement

# Omitiendo --skill se actualizan todas las skills ya instaladas localmente (update.sh no tiene flag --all)
./cli/update.sh
```

#### **PowerShell**
```powershell
.\cli\update.ps1 -Skill us-refinement

# Omitiendo -Skill se actualizan todas las skills ya instaladas localmente (update.ps1 no tiene flag -All)
.\cli\update.ps1
```

### 3. Desinstalación

Desinstalá una skill específica o todas las skills de tus entornos de agentes y del almacenamiento central:

#### **Linux / macOS (Bash)**
```bash
# Desinstalación mediante script remoto (1 línea)
curl -fsSL https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/uninstall.sh | bash -s -- --skill us-refinement
curl -fsSL https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/uninstall.sh | bash -s -- --all

# O ejecutar localmente desde clone o almacenamiento central (~/.hjagar/skills/)
./cli/uninstall.sh --skill us-refinement
./cli/uninstall.sh --all
```

#### **Windows (PowerShell)**
```powershell
# Desinstalación mediante script remoto (1 línea)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/uninstall.ps1))) -Skill us-refinement
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hjagar/hjagar-skills/main/cli/uninstall.ps1))) -All

# O ejecutar localmente desde clone o almacenamiento central (~/.hjagar/skills/)
.\cli\uninstall.ps1 -Skill us-refinement
.\cli\uninstall.ps1 -All
```

---

## 🏗️ Arquitectura Monorepo

El proyecto mantiene una separación clara entre **desarrollo/mantenimiento** y **distribución/consumo**:

- **Única Fuente de Verdad**: Todo el código fuente, validadores de calidad y herramientas CLI viven en `hjagar-skills`.

---

## 📦 Gestión de Releases

Para validar calidad, incrementar versión, empaquetar y publicar un release en GitHub para una skill:

#### **Bash**
```bash
./cli/Release-Repo.sh patch --skill us-refinement
```

#### **PowerShell**
```powershell
.\cli\Release-Repo.ps1 -ReleaseType minor -Skill req-discovery
```

---

<a name="license"></a>
<a name="licencia"></a>
## 📜 License / Licencia

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more details.

Distribuido bajo la Licencia MIT. Ver [`LICENSE`](LICENSE) para más detalles.
