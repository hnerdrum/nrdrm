import { ignorePatterns, next, node } from 'eslint-config-nrdrm';

const source = '**/*.{js,jsx,cjs,mjs,ts,tsx}';

function inDir(configs, dir) {
  return configs.flatMap((config) => {
    if (
      config.ignores &&
      !config.files &&
      !config.rules &&
      !config.plugins &&
      !config.languageOptions
    ) {
      return [];
    }
    const patterns = config.files ?? [source];
    return [
      {
        ...config,
        files: patterns.map((pattern) => `${dir}/${pattern}`),
      },
    ];
  });
}

export default [
  { ignores: ignorePatterns },
  ...inDir(node, 'server/agents'),
  ...inDir(node, 'cron/delete-container-images'),
  ...inDir(node, 'web/training'),
  ...inDir(node, 'web/home'),
  ...inDir(next, 'web/recipes'),
];
