# ORTA Backend Milestone 1

Local Node/TypeScript backend for the ORTA Agent. It forwards structured ORTA context to the OpenAI Responses API without exposing the API key to Flutter.

## Setup

```sh
cd backend
npm install
cp .env.example .env
```

Open `backend/.env` and personally set:

```env
OPENAI_API_KEY=your_real_key_here
PORT=3000
```

Never paste the key into Flutter or commit `.env`.

## Run

```sh
cd backend
npm run dev
```

Health check: `GET http://localhost:3000/health`
Agent endpoint: `POST http://localhost:3000/api/agent/message`

The backend uses model `gpt-5.6-terra` through the OpenAI Responses API. Without `OPENAI_API_KEY`, the server still starts and health works, while the agent endpoint returns a safe configuration error.
