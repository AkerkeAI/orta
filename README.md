# ORTA

ORTA is an AI Life Operating System: an AI system for managing life context, goals, projects, deadlines, responsibilities, opportunities and available time. Its core question is:

> Given who a person is, what they want, what is happening in their life, and how much time they actually have, what needs to happen next?

ORTA is being developed as a coordinated system rather than a standalone chatbot, calendar or to-do list. The user remains in control and important actions require approval.

## The problem

The information that shapes a person's life is distributed across calendars, messages, documents, education, projects, exams and deadlines. People have to remember the connections themselves, decide what matters next and fit actions into the time they actually have.

## How ORTA works

The system is designed around five connected ideas:

- **Life context:** a structured, continuously updated view of the user's goals, projects, responsibilities and current situation.
- **Goals and progress:** long-term intentions are decomposed into stages and observable actions.
- **Time and planning:** actions are considered against events, deadlines and available time.
- **AI reasoning:** ORTA reasons over relationships between life context, goals and time to produce relevant recommendations.
- **User-approved actions:** ORTA proposes; the user decides whether an action is added or carried out.

## Current status

ORTA is in active development. This repository contains an early Flutter application, a TypeScript backend with ORTA Agent logic, and a public-facing landing page. Integrations and automation described in the roadmap are planned functionality, not completed capabilities.

## Architecture

```text
Flutter app  <----HTTP---->  TypeScript / Express backend  <---->  AI provider
     |                                  |
     +-- local user state                +-- ORTA Agent and domain types

Landing page: standalone Vite site in landing/
```

### Flutter app

The Flutter project is the cross-platform application in the repository root. It contains the current UI, models, services, localization and theme code for the ORTA product experience. Platform folders for Android, iOS, macOS, Linux, Windows and web are included as Flutter project targets.

### Backend and ORTA Agent

`backend/` contains the TypeScript/Express service and the ORTA Agent implementation. Runtime secrets are loaded from a local `backend/.env` file and must never be committed. Use `backend/.env.example` as the variable-name template and provide your own `OPENAI_API_KEY` locally when running the backend.

Backend commands:

```bash
cd backend
npm install
npm run typecheck
npm run dev
```

### Landing page

`landing/` is a lightweight Vite site for the Russian ORTA product story. It is intentionally separate from the Flutter app so it can deploy independently to Vercel. The email interest form posts to Formspree and reports success only after a successful server response.

Run it locally from the repository root:

```bash
npm --prefix landing install
npm --prefix landing run dev
```

Build it for production:

```bash
npm --prefix landing run build
```

## Roadmap

### MVP / current development

- Life context
- Goals and projects
- Planning model
- ORTA Agent foundation
- AI recommendations

### Planned next

- Calendar integration
- Opportunity discovery
- Language ORTA
- Progress analysis

### Longer-term vision

- Email and document context
- Web search
- Controlled automation

These roadmap items are not claims that the integrations or automation are already available.

## Security and repository hygiene

Secrets, local environment files, dependency folders, build output, signing files, machine-specific configuration and generated Flutter configuration are excluded by `.gitignore`. Do not place API keys, service-account files, signing credentials or private tokens in source code.

## License

No public license has been selected yet.
