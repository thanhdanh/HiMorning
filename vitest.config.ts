import { defineConfig } from 'vitest/config';
export default defineConfig({ test: { testTimeout: 15000, include: ['tests/**/*.test.ts'], coverage: { provider: 'v8', include: ['functions/src/**/*.ts'], reporter: ['text', 'json-summary', 'html'], thresholds: { lines: 80, branches: 80, functions: 80, statements: 80 } } } });
