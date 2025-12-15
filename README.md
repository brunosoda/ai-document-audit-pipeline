# AI Document Audit Pipeline

Production-style AI-powered audit pipeline for automated document verification, designed to identify validation errors and improve approval accuracy in production workflows, using LLMs, SQL, and workflow orchestration.

---

## Problem Statement

Automated document verification systems can incorrectly approve invalid documents due to logic flaws, data inconsistencies, or model limitations.  
Without systematic auditing, these errors may remain unnoticed and propagate through production systems.

This project implements an automated audit pipeline to review document approval results, validate decision criteria, and support continuous improvement of automated verification processes.

---

## Solution Overview

The pipeline audits automated document approval results by:

1. Extracting document images and metadata from storage
2. Validating input data and audit criteria
3. Running LLM-based audits using structured, few-shot prompts
4. Producing structured JSON outputs for analysis and monitoring
5. Supporting identification and correction of validation errors in production workflows

---

## Architecture

The solution is composed of the following components:

- **SQL layer** for data extraction, joins, and result storage
- **Workflow orchestration** using n8n
- **LLM-based audit logic** for document verification and criteria evaluation
- **Structured JSON outputs** to ensure consistency and downstream usability

The pipeline is designed to be modular, auditable, and extensible.

---

## Tech Stack

- Python (automation and validation logic)
- SQL (MySQL / PostgreSQL)
- AWS S3 (object storage)
- n8n (workflow orchestration)
- OpenAI-compatible LLMs
- JSON-based audit outputs

---

## Repository Structure

```text
.
├── n8n/          # Sanitized n8n workflow export
├── sql/          # Data extraction, joins, and insertion queries
├── src/          # Audit, prompt, and validation logic
├── examples/     # Sample input and output JSON files
├── architecture/ # Pipeline diagrams and documentation
└── README.md
