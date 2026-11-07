import { fixupPluginRules } from '@eslint/compat';
import stylistic from '@stylistic/eslint-plugin';
import importPlugin from 'eslint-plugin-import';
import unusedImports from 'eslint-plugin-unused-imports';
import globals from 'globals';
import tseslint from 'typescript-eslint';

const importPluginFixed = fixupPluginRules(importPlugin);

// Values referenced via `typeof` / type queries are used. typescript-eslint
// reports them as unused because they are erased at runtime; unique-symbol
// sentinels and similar type-level markers are a legitimate exception.
// https://github.com/typescript-eslint/typescript-eslint/issues/10266
function allowTypeOnlyUsage(rule) {
  return {
    ...rule,
    create(context) {
      return rule.create(
        Object.create(context, {
          report: {
            enumerable: true,
            value(problem) {
              if (problem.messageId === 'usedOnlyAsType') {
                return;
              }
              context.report(problem);
            },
          },
        }),
      );
    },
  };
}

const unusedImportsPlugin = {
  ...unusedImports,
  rules: {
    ...unusedImports.rules,
    'no-unused-vars': allowTypeOnlyUsage(unusedImports.rules['no-unused-vars']),
  },
};

export const typeScriptExtensions = ['.ts', '.cts', '.mts', '.tsx', '.d.ts'];
export const allExtensions = [
  ...typeScriptExtensions,
  '.js',
  '.jsx',
  '.mjs',
  '.cjs',
  '.json',
];

export const parserOptions = {
  ecmaVersion: 'latest',
  sourceType: 'module',
};

export const importSettings = {
  'import/parsers': {
    '@typescript-eslint/parser': typeScriptExtensions,
  },
  'import/resolver': {
    node: {
      extensions: allExtensions,
    },
  },
  'import/extensions': ['.js', '.mjs', '.jsx', '.ts', '.tsx', '.d.ts'],
  'import/external-module-folders': ['node_modules', 'node_modules/@types'],
};

export const sharedRestrictedImportPatterns = [
  {
    group: ['^console$'],
    message: 'Do not import built-ins like this',
  },
];

// Dev-only files that may import devDependencies. Test files also have the rule
// turned off in sharedOverrides; these globs cover tooling config entrypoints.
export const devDependencyAllowlist = [
  'test/**',
  'tests/**',
  'spec/**',
  '**/__tests__/**',
  '**/__mocks__/**',
  'test.{js,jsx,ts,tsx}',
  'test-*.{js,jsx,ts,tsx}',
  '**/*{.,_}{test,spec}.{js,jsx,ts,tsx}',
  '**/jest.config.js',
  '**/jest.config.cjs',
  '**/jest.setup.js',
  '**/jest.setup.ts',
  '**/eslint.config.mjs',
  '**/vite.config.ts',
  '**/svelte.config.js',
  '**/tailwind.config.ts',
  '**/postcss.config.js',
  '**/next.config.mjs',
  '**/drizzle.config.ts',
  '**/astro.config.mjs',
];

export const sharedPlugins = {
  import: importPluginFixed,
  'unused-imports': unusedImportsPlugin,
  '@stylistic': stylistic,
};

export const sharedRules = {
  '@typescript-eslint/consistent-type-imports': 'error',
  // #5893
  '@typescript-eslint/no-explicit-any': 'off',
  // '@typescript-eslint/no-explicit-any': ['error', { fixToUnknown: true }],
  '@typescript-eslint/no-non-null-assertion': 'off',
  '@typescript-eslint/no-inferrable-types': 'off',
  '@typescript-eslint/no-empty-function': 'off',
  '@typescript-eslint/no-non-null-asserted-optional-chain': 'off',
  '@typescript-eslint/no-require-imports': 'off',
  '@typescript-eslint/no-empty-object-type': 'off',
  '@typescript-eslint/no-unused-vars': 'off',
  '@typescript-eslint/no-namespace': 'off',
  'import/namespace': 'off',
  'import/default': 'off',
  'import/no-named-as-default': 'off',
  'import/no-named-as-default-member': 'off',
  'import/no-duplicates': 'off',
  'import/export': 'off',
  'import/no-extraneous-dependencies': [
    'error',
    {
      devDependencies: devDependencyAllowlist,
      optionalDependencies: false,
    },
  ],
  'no-restricted-syntax': [
    'error',
    'ForInStatement',
    'LabeledStatement',
    'WithStatement',
  ],
  'no-await-in-loop': 'off',
  'no-continue': 'off',
  curly: ['error', 'all'],
  'no-implied-eval': 'error',
  '@typescript-eslint/no-implied-eval': 'off',
  '@typescript-eslint/only-throw-error': 'off',
  '@typescript-eslint/return-await': 'off',
  'dot-notation': 'error',
  '@typescript-eslint/dot-notation': 'off',
  '@typescript-eslint/ban-ts-comment': 'warn',
  'no-restricted-imports': [
    'error',
    {
      patterns: sharedRestrictedImportPatterns,
    },
  ],
  'import/order': [
    'error',
    {
      alphabetize: {
        order: 'asc',
      },
      'newlines-between': 'always',
      groups: ['builtin', 'external', 'internal', 'parent', 'sibling', 'index'],
    },
  ],
  '@typescript-eslint/no-restricted-types': [
    'error',
    {
      types: {
        String: {
          message: 'Use string instead',
          fixWith: 'string',
        },
        '{}': {
          message:
            '{} allows a function to be called with any argument.\n' +
            '  - Consider removing the typing entirely.\n' +
            '  - If you explicitly want any Record, use Record<string, unknown>.\n' +
            '  - If you explicitly want an empty object, use Record<never, never>.\n' +
            '  - If you want to allow anything (discouraged), use unknown.',
          fixWith: '',
        },
        'React.FC': {
          message:
            'You do not need to type the return type of a React component. React.FC is discouraged. See https://github.com/facebook/create-react-app/pull/8177',
        },
        FC: {
          message:
            'You do not need to type the return type of a React component. React.FC is discouraged. See https://github.com/facebook/create-react-app/pull/8177',
        },
      },
    },
  ],
  '@typescript-eslint/no-use-before-define': [
    'error',
    {
      functions: false,
      classes: false,
      variables: false,
      typedefs: false,
    },
  ],
  '@typescript-eslint/no-unused-expressions': [
    'error',
    {
      allowShortCircuit: true,
      allowTernary: true,
      allowTaggedTemplates: true,
      enforceForJSX: false,
    },
  ],
  '@stylistic/lines-between-class-members': [
    'error',
    'always',
    { exceptAfterSingleLine: true },
  ],
  'unused-imports/no-unused-imports': 'error',
  'unused-imports/no-unused-vars': [
    'error',
    {
      ignoreRestSiblings: true,
      vars: 'all',
      varsIgnorePattern: '^_',
      args: 'after-used',
      argsIgnorePattern: '^_',
      caughtErrors: 'none',
    },
  ],
  'no-console': 'error',
  'no-param-reassign': [
    'error',
    {
      props: true,
      ignorePropertyModificationsFor: ['acc', 'e'],
    },
  ],
  'no-constant-binary-expression': 'off',
  'no-empty-static-block': 'off',
  'no-unused-private-class-members': 'off',
  'no-useless-assignment': 'off',
  'no-unassigned-vars': 'off',
  'preserve-caught-error': 'off',
};

export const sharedOverrides = [
  {
    files: ['**/*.{ts,tsx}'],
    rules: {
      'constructor-super': 'off',
      'getter-return': 'off',
      'no-const-assign': 'off',
      'no-dupe-args': 'off',
      'no-dupe-class-members': 'off',
      'no-dupe-keys': 'off',
      'no-func-assign': 'off',
      'no-import-assign': 'off',
      'no-new-native-nonconstructor': 'off',
      'no-obj-calls': 'off',
      'no-redeclare': 'off',
      'no-setter-return': 'off',
      'no-this-before-super': 'off',
      'no-undef': 'off',
      'no-unreachable': 'off',
      'no-unsafe-negation': 'off',
      'valid-typeof': 'off',
      'import/named': 'off',
      'import/no-named-as-default-member': 'off',
      'import/no-unresolved': 'off',
    },
  },
  {
    files: ['**/*.cjs'],
    languageOptions: {
      sourceType: 'commonjs',
    },
    rules: {
      'import/order': 'off',
    },
  },
  {
    files: ['**/*.stories.*'],
    rules: {
      'import/no-anonymous-default-export': 'off',
      '@typescript-eslint/no-empty-function': 'off',
      'import/no-extraneous-dependencies': 'off',
      'no-console': 'off',
    },
  },
  {
    files: ['**/generated/*.ts', '**/generated.ts'],
    rules: {
      'import/order': 'off',
      '@typescript-eslint/naming-convention': 'off',
    },
  },
  {
    files: [
      '**/*.test.ts',
      '**/*.test.tsx',
      '**/*.test.data.ts',
      '**/tests/**',
      '**/__mocks__/**',
      '**/*.stories.ts',
      '**/*.stories.tsx',
      '**/jest.setup.ts',
      '**/jest.setup.js',
      '**/*.js',
      '**/*.cjs',
      '**/*.mjs',
      '**/prisma/**',
      '**/prisma.config.ts',
      '**/emails/**',
      '**/codegen*.ts',
      'index.ts',
      'index.tsx',
    ],
    extends: [tseslint.configs.disableTypeChecked],
  },
  {
    files: [
      '**/*.test.ts',
      '**/*.test.data.ts',
      '**/*.spec.ts',
      '**/tests/**',
      '**/seed.data.ts',
      '**/jest.setup.js',
    ],
    languageOptions: {
      globals: globals.jest,
    },
    rules: {
      'import/no-extraneous-dependencies': 'off',
      'unused-imports/no-unused-vars': [
        'warn',
        {
          ignoreRestSiblings: true,
          vars: 'all',
          varsIgnorePattern: '^_',
          args: 'after-used',
          argsIgnorePattern: '^_',
          caughtErrors: 'none',
        },
      ],
      'no-console': 'off',
    },
  },
  {
    files: ['**/scripts/**'],
    rules: {
      'no-console': 'off',
    },
  },
];
