# LLM Stack - Complete Documentation

The LLM stack in Balor allows using local AI models for cybersecurity tasks with multi-model support and configurable personas.

## Table of contents

1. Installation
2. Model selection
3. Usage
4. Personas
5. Model management
6. Customization

---

## Installation

### Prerequisites

- Ollama installed
- At least 8 GB RAM recommended
- ~4-5 GB disk per base model (GGUF)

### Install the stack

```bash
cd /path/to/Balor
sudo bash stacks/llm/install.sh
```

During install you'll be prompted to choose model(s) to install.

---

## Model management and storage

### Where models live

- Source GGUF files: `/opt/balorsh/data/llm/models/`
- Active Ollama storage: `~/.ollama/models/` (internal blobs/manifests)
- Modelfiles (personas) used for Ollama: `/opt/balorsh/data/llm/modelfiles/`

Each model typically requires ~2x disk: the GGUF source plus Ollama blobs.

### Models JSON (versions/status)

Balor maintains a JSON summary of Modelfiles and versions at:

`/opt/balorsh/json/models_status.json`

This file contains `last_update` and a `models` object mapping persona names to their `version` and `installed` state. It is produced by the `update_models_json()` helper in `lib/common.sh`.

When a discrepancy is detected between the `VERSION` file in the repository (lines like `Modelfile.<persona>:<version>`) and the JSON, Balor will run `check_and_recreate_models_if_needed()` which:

1. Reads the declared version from `VERSION`.
2. Compares it with the value in `/opt/balorsh/json/models_status.json`.
3. If different, recreates the Modelfile for the currently active base model (from `active_model.txt`), runs `ollama rm` then `ollama create` for `balor:<persona>`.
4. Updates the JSON via `update_models_json()`.

This mechanism ensures personas are kept consistent with the repository versioning and allows non-interactive tooling to query the JSON for model status.

---

## Usage

Run the LLM menu:

```bash
./balorsh llm
```

Use menu entries to switch active model, create/delete personas, analyze logs or chat with the AI. See `stacks/llm/commands.sh` for the exact menu and prompts.

---

## Personas and Modelfiles

Personas are Modelfiles in `lib/models/` (e.g. `Modelfile.base`, `Modelfile.loganalyst`). When switching models, Balor copies and patches these Modelfiles to point to the selected GGUF file and creates corresponding Ollama models (namespaced `balor:<persona>`).

To add a persona, create `lib/models/Modelfile.<name>` and declare its version in `VERSION` as `Modelfile.<name>:<version>` so it appears in the JSON.

---

## Troubleshooting

- If models are not listed or versions mismatch, check `/opt/balorsh/json/models_status.json` and run `update_models_json()` (via the installer or manually by sourcing `lib/common.sh`).
- To recreate models manually, copy Modelfiles to `/opt/balorsh/data/llm/modelfiles/` updated with the active GGUF path and run `ollama create balor:<persona> -f <Modelfile>`.

---

See also: `lib/common.sh` (functions `update_models_json`, `check_and_recreate_models_if_needed`) and `stacks/llm/commands.sh`.
