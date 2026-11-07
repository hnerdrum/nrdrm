import js from '@eslint/js';
import eslintConfigPrettier from 'eslint-config-prettier';
import globals from 'globals';
import tseslint from 'typescript-eslint';

import { ignorePatterns } from './ignores.js';
import {
  parserOptions,
  importSettings,
  sharedPlugins,
  sharedRules,
  sharedOverrides,
} from './shared.js';

export const node = tseslint.config(
  { ignores: ignorePatterns },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  eslintConfigPrettier,
  {
    name: 'nrdrm/node',
    files: ['**/*.{js,jsx,cjs,mjs,ts,tsx}'],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions,
      globals: globals.node,
    },
    plugins: sharedPlugins,
    settings: importSettings,
    rules: {
      ...sharedRules,
      'no-console': 'off',
    },
  },
  ...sharedOverrides,
);
