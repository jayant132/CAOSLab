# ChaosLab

### AI-Powered Scalability & Resilience Simulation Platform

ChaosLab is an AI-powered engineering platform that analyzes a GitHub repository, reconstructs its service architecture, simulates scalability and failure scenarios, and uses a multi-agent reasoning pipeline to identify potential bottlenecks and recommend remediation strategies.

> **Give ChaosLab a public GitHub repository and a scenario such as *"What happens if traffic increases from 100K to 10M users?"* — it reconstructs the architecture, runs a deterministic capacity simulation, investigates the highest-risk component, and generates an evidence-backed remediation report.**

![Status](https://img.shields.io/badge/status-active-3ECF8E)
![Backend](https://img.shields.io/badge/backend-FastAPI%20%7C%20LangGraph-4FD1C5)
![AI](https://img.shields.io/badge/AI-Groq%20%7C%20Llama%203.3-8C9BB0)
![Frontend](https://img.shields.io/badge/frontend-Flutter%20%7C%20MVVM-4FD1C5)
![Streaming](https://img.shields.io/badge/streaming-SSE-8C9BB0)
![License](https://img.shields.io/badge/license-MIT-8C9BB0)

---

## Overview

Modern systems can fail long before they reach their theoretical maximum capacity.

ChaosLab explores these failure points by combining:

* **Repository intelligence** to reconstruct system architecture
* **Deterministic capacity modeling** to estimate system behavior under load
* **Failure injection scenarios** to model common infrastructure failures
* **Multi-agent LLM reasoning** to investigate bottlenecks
* **Evidence-based verification** to prevent unsupported conclusions
* **Real-time SSE streaming** to expose the pipeline as it executes
* **Flutter MVVM frontend** for an interactive engineering workflow

The result is an engineering report that connects:

**Repository → Architecture → Scenario → Simulation → Bottleneck → Failure Chain → Remediation**

---

## Why ChaosLab?

Traditional LLM applications often follow:

```text
User Question → LLM → Answer
```

ChaosLab deliberately separates **reasoning** from **computation**.

```text
                    ┌─────────────────────┐
                    │   GitHub Repository │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Architecture Agent  │
                    │   LLM Reasoning     │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Simulation Engine   │
                    │ Deterministic Math  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Investigator Agent  │
                    │ Evidence + Analysis │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Remediation Agent   │
                    │ Engineering Actions │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Final Report      │
                    └─────────────────────┘
```

LLMs handle interpretation and reasoning.

The deterministic simulation engine handles measurable calculations such as:

* Service utilization
* Estimated latency
* Estimated error rate
* Capacity pressure
* Failure impact
* Risk scoring

This separation makes the system easier to reason about, test, and explain.

---

## Key Engineering Highlights

### 1. Repository-to-Architecture Reconstruction

ChaosLab accepts a public GitHub repository and attempts to reconstruct its architecture from actual repository evidence.

When a `docker-compose.yml` exists, ChaosLab extracts:

* Services
* Dependencies
* Network relationships
* Resource limits
* Replica counts

When Compose is unavailable, the system analyzes repository signals such as:

* `package.json`
* `requirements.txt`
* `go.mod`
* `Gemfile`
* `pom.xml`
* `Dockerfile`
* Database dependencies
* Cache dependencies
* Queue dependencies
* Search infrastructure

The system only introduces infrastructure components when supported by repository evidence.

This avoids blindly generating a standard architecture template.

---

### 2. Deterministic Capacity Simulation

The simulation engine is intentionally separate from the LLM layer.

Given the reconstructed architecture and target scenario, ChaosLab models:

```text
Traffic
   ↓
Service Capacity
   ↓
Utilization
   ↓
Latency / Errors
   ↓
Failure Propagation
   ↓
Risk
```

The model produces estimated metrics that downstream agents can reason over.

The same inputs produce the same simulation results, making the computation reproducible and independently testable.

---

### 3. Multi-Agent LangGraph Pipeline

ChaosLab uses a typed LangGraph workflow with four specialized stages.

| Stage              | Responsibility                       | Type                             |
| ------------------ | ------------------------------------ | -------------------------------- |
| Architecture Agent | Interpret repository topology        | LLM                              |
| Simulation Agent   | Execute capacity/failure model       | Deterministic                    |
| Investigator Agent | Identify and verify bottlenecks      | LLM + deterministic verification |
| Remediation Agent  | Generate engineering recommendations | LLM                              |

Each agent has a clearly defined responsibility rather than relying on a single general-purpose prompt.

---

### 4. Evidence-Based Investigation

The Investigator does not simply accept an LLM-generated bottleneck.

Its conclusion is checked against the simulation evidence.

Conceptually:

```text
LLM Claim
    │
    ▼
Measured Simulation Evidence
    │
    ├── Supports claim ──→ Continue
    │
    └── Contradicts claim → Bounded revision
```

This creates a controlled feedback loop where reasoning remains grounded in the deterministic simulation output.

---

### 5. Real-Time Agent Execution

The backend exposes the simulation through Server-Sent Events.

```http
GET /api/v1/simulation/stream/{simulation_id}
```

The Flutter client receives agent progress as the pipeline executes:

```text
Architecture
      ↓
Simulation
      ↓
Investigation
      ↓
Remediation
      ↓
Final Report
```

This makes the multi-agent workflow observable rather than hiding the entire process behind a single loading state.

---

## Example Scenario

A user submits:

```text
Repository:
github.com/example/production-api

Scenario:
Traffic increases from 100K to 10M users.

Failure scenario:
Database latency increases by 300%.
```

ChaosLab performs:

```text
1. Inspect repository
        ↓
2. Reconstruct architecture
        ↓
3. Define workload
        ↓
4. Run deterministic simulation
        ↓
5. Measure service pressure
        ↓
6. Investigate highest-risk component
        ↓
7. Verify conclusion against simulation evidence
        ↓
8. Generate remediation plan
```

The resulting report can identify:

* Primary bottleneck
* Estimated utilization
* Estimated latency impact
* Estimated error impact
* Failure propagation chain
* Supporting evidence
* Recommended remediation steps

---

## Repository Intelligence

ChaosLab supports two architecture discovery paths.

### Path A — Docker Compose

```text
docker-compose.yml
        ↓
Services
        ↓
Dependencies
        ↓
Resources / Replicas
        ↓
ArchitectureGraph
```

### Path B — Repository Signal Analysis

For repositories without Compose:

```text
Repository Tree
      ↓
Manifest Detection
      ↓
Dependency Detection
      ↓
Infrastructure Signals
      ↓
ArchitectureGraph
```

For example, a repository containing:

```text
package.json
Dockerfile
redis dependency
postgres dependency
```

can provide evidence for an architecture containing application, cache, and database components.

A repository without recognizable infrastructure signals is instead represented as a generic service and explicitly marked as unconfirmed.

Every inferred architecture contains:

```text
used_fallback
fallback_reason
```

so users can distinguish repository evidence from inference.

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                         Flutter Client                      │
│                         MVVM Architecture                   │
└────────────────────────────┬────────────────────────────────┘
                             │ HTTP / SSE
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                         FastAPI API                         │
├─────────────────────────────────────────────────────────────┤
│ Repository Inspection │ Simulation │ Streaming │ Reporting │
└───────────────┬───────────────────────┬─────────────────────┘
                │                       │
                ▼                       ▼
      ┌─────────────────┐     ┌─────────────────────┐
      │ GitHub REST API │     │ Deterministic Model │
      └─────────────────┘     └──────────┬──────────┘
                                         │
                                         ▼
                              ┌──────────────────────┐
                              │     LangGraph        │
                              │                      │
                              │ Architecture Agent   │
                              │ Simulation Agent     │
                              │ Investigator Agent   │
                              │ Remediation Agent    │
                              └──────────┬───────────┘
                                         │
                                         ▼
                                   Final Report
```

---

## Technology Stack

| Area                  | Technology                 |
| --------------------- | -------------------------- |
| Frontend              | Flutter                    |
| Frontend Architecture | MVVM + ChangeNotifier      |
| Backend               | FastAPI                    |
| API Validation        | Pydantic                   |
| Agent Orchestration   | LangGraph                  |
| LLM                   | Groq / Llama 3.3 70B       |
| Repository Analysis   | GitHub REST API            |
| Configuration Parsing | PyYAML                     |
| Streaming             | Server-Sent Events         |
| HTTP Client           | Dio                        |
| Language              | Python + Dart              |
| Storage               | In-memory simulation store |
| License               | MIT                        |

---

## API

ChaosLab uses explicitly namespaced API routes.

| Method | Endpoint                         | Description                                  |
| ------ | -------------------------------- | -------------------------------------------- |
| `GET`  | `/api/v1/system/pulse`           | Backend liveness and AI configuration status |
| `POST` | `/api/v1/repository/inspect`     | Inspect a public GitHub repository           |
| `POST` | `/api/v1/simulation/execute`     | Start a simulation                           |
| `GET`  | `/api/v1/simulation/stream/{id}` | Stream live pipeline events                  |
| `GET`  | `/api/v1/simulation/report/{id}` | Retrieve simulation report                   |

---

## Project Structure

```text
chaoslab/
│
├── backend/
│   ├── app/
│   │   ├── agents/
│   │   ├── api/
│   │   ├── core/
│   │   ├── models/
│   │   ├── services/
│   │   └── main.py
│   │
│   └── README.md
│
├── frontend/
│   └── chaoslab_flutter/
│       ├── lib/
│       └── README.md
│
└── README.md
```

---

## Getting Started

### Prerequisites

* Python 3.10+
* Flutter SDK
* Git
* A public GitHub repository for analysis
* Optional: Groq API key

### 1. Clone

```bash
git clone https://github.com/jayant132/CAOSLab.git
cd CAOSLab
```

### 2. Start the Backend

```bash
cd backend

python3 -m venv venv
source venv/bin/activate

pip install -r requirements.txt

cp .env.example .env

uvicorn app.main:app --reload --port 8000
```

### 3. Start the Flutter Client

In another terminal:

```bash
cd frontend/chaoslab_flutter

flutter pub get

flutter run
```

---

## AI Configuration

ChaosLab can run without an external LLM API key.

When `GROQ_API_KEY` is not configured, the reasoning stages use deterministic fallback behavior so the complete pipeline remains executable.

To enable LLM-powered reasoning:

```env
GROQ_API_KEY=your_key_here
```

Groq API keys can be configured through the Groq developer console.

---

## Important Scope Boundary

ChaosLab is a **capacity simulation and architecture reasoning platform**, not a production load-testing system.

It does not:

* Deploy infrastructure
* Generate real production traffic
* Benchmark a live deployment
* Measure real-world latency from physical infrastructure
* Guarantee that predicted capacity matches production behavior

Instead, ChaosLab uses a deterministic queueing-style capacity model to produce **engineering estimates** from the reconstructed architecture and selected scenario.

This distinction is intentional.

The platform is designed to demonstrate how **repository intelligence, deterministic modeling, and LLM-based reasoning can be combined into an auditable engineering workflow**.

---

## Engineering Decisions

### Why LangGraph?

LangGraph provides explicit state and control flow for multi-step agent workflows.

This makes the pipeline easier to:

* Trace
* Test
* Extend
* Stream
* Debug
* Control

### Why deterministic simulation?

LLMs are useful for reasoning but should not be responsible for producing critical numerical calculations.

Separating simulation from reasoning makes the numerical layer:

* Reproducible
* Testable
* Explainable
* Independent of model behavior

### Why SSE?

Simulation is inherently asynchronous.

SSE allows the frontend to receive pipeline events without repeatedly polling the backend.

### Why Flutter?

Flutter provides a single cross-platform client while allowing the simulation workflow to be represented as an interactive engineering dashboard.

---

## Current Limitations

ChaosLab is currently a portfolio/demo system with intentionally limited infrastructure.

* Public GitHub repositories only
* No GitHub OAuth/private repository support
* No authentication layer
* In-memory simulation storage
* No distributed job queue
* No persistent simulation history
* No real infrastructure provisioning
* No live load testing

These are architectural boundaries rather than hidden assumptions.

---

## Future Improvements

Potential production extensions include:

* GitHub OAuth and private repository analysis
* Persistent PostgreSQL/Redis storage
* Distributed simulation workers
* Kubernetes topology discovery
* OpenTelemetry integration
* Real load-test integration
* Historical simulation comparison
* Persistent architecture graphs
* Authentication and multi-tenancy
* Cloud infrastructure modeling
* Cost estimation
* Production observability integrations

---

## What This Project Demonstrates

ChaosLab combines several areas of modern software engineering:

**AI Engineering**

* LangGraph
* Multi-agent workflows
* LLM orchestration
* Evidence-grounded reasoning
* Bounded self-verification

**Backend Engineering**

* FastAPI
* Async processing
* SSE streaming
* Pydantic contracts
* API design

**Systems Engineering**

* Architecture reconstruction
* Capacity modeling
* Bottleneck analysis
* Failure propagation
* Resilience planning

**Frontend Engineering**

* Flutter
* MVVM
* Reactive state management
* Real-time pipeline visualization

---

## License

MIT — see [`LICENSE`](LICENSE).

---

### Built as an exploration of AI-assisted systems engineering

ChaosLab is designed around a simple engineering principle:

> **Use AI to reason about systems, but use deterministic computation to measure them.**
