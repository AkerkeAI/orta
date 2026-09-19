const useRemoteOrtaAgent = bool.fromEnvironment(
  'ORTA_USE_REMOTE_AGENT',
  defaultValue: true,
);
const ortaBackendBaseUrl = String.fromEnvironment(
  'ORTA_BACKEND_URL',
  defaultValue: 'http://127.0.0.1:3000',
);
