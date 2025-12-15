# LLM Stack - Multi-Model AI

[Version française](balorsh_llm_fr.md)

The LLM stack in Balor now supports multiple AI models.

## Installation

During installation, you can choose from:

1. **Seneca Cybersecurity LLM** (7B, Q4_K_M) - Recommended
   - Specialized in cybersecurity
   - Optimized for log analysis and security

2. **WhiteRabbitNeo 2.5 Qwen Coder** (7B, Q4_K_M)
   - Specialized in coding and offensive security
   - Excellent programming capabilities

3. **Both models**
   - You can switch between the two

4. **Custom model**
   - Provide a URL to a GGUF file

## Usage

### LLM Menu

The menu offers:

**AI MODELS**
- **1. Load/Switch AI model** - Switch between installed models
- **2. Delete an AI model** - Remove a model and its personas

**INTERACTION**
- **3. Analyze a log** - Submit a log file to the AI
- **4. Chat with AI** - Interactive conversation

**PERSONAS** (dynamic)
- Automatic list based on available Modelfiles

**SYSTEM**
- Stop Ollama
- View conversations
- View analyses

### Switching Models

When you switch the active model:
1. All Modelfiles are recreated with the new model
2. All Ollama personas are recreated
3. The new model becomes active immediately

### Deleting a Model

When deleting a model:
1. The GGUF file is deleted
2. It is removed from the configuration
3. If it was the active model, another is automatically selected
4. Ollama personas are not deleted (but will be invalid)

## Configuration Files

- `/opt/balorsh/data/llm/models/models.conf` - List of installed models
- `/opt/balorsh/data/llm/models/active_model.txt` - Currently active model
- `/opt/balorsh/data/llm/models/*.gguf` - Model files
- `/opt/balorsh/data/llm/modelfiles/Modelfile.*` - Persona definitions

## Adding a New Model

To manually add a model after installation:

```bash
# Download the model
cd /opt/balorsh/data/llm/models
curl -L -o mymodel.gguf "MODEL_URL"

# Add to configuration
echo "mymodel.gguf|My Custom Model" >> models.conf

# The model will appear in menu option 1
```

## Personas

Personas are automatically adapted to the active model. Source Modelfiles in `lib/models/` are copied and modified to point to the correct model.

To add a persona, see [lib/models/README.md](../../lib/models/README.md).
