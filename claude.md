# Claude Code Configuration

This is an OpenClaw + LiteLLM + GCP setup project using PowerShell scripts.

## Project Overview
- **Purpose**: Automated setup of OpenClaw with LiteLLM proxy and GCP Vertex AI
- **Language**: PowerShell (Windows)
- **Key Files**:
  - `setup.ps1` - Main installation script
  - `audit_pc.ps1` - System audit script
  - `check_all.ps1` - Verification script
  - `litellm/config.yaml` - LiteLLM configuration
  - `cloudflare/config.yml` - Cloudflare Tunnel configuration

## Setup Instructions

### Prerequisites
- Windows with PowerShell 7+
- Administrator access
- GCP account with Vertex AI enabled
- LiteLLM and OpenClaw installed

### Quick Start
```powershell
# Run as Administrator
.\audit_pc.ps1
.\setup.ps1
.\check_all.ps1
```

## API Configuration
- Provider: OpenAI-Compatible
- Base URL: http://127.0.0.1:4000
- Default Model: sonnet-4.5

## Notes
- GCP Budget: $199 for 3 months
- Supports fallbacks to Llama 3.3 and Mixtral
- Uses Cloudflare Tunnel for remote access
