import { readFileSync } from 'node:fs';
import path from 'node:path';

import { type ToolSet } from 'ai';

export type Skill = {
  readonly name: string;
  readonly instructions: string;
  readonly tools: ToolSet;
};

const skillName = /^[a-z0-9][a-z0-9-]*$/;

export const loadSkill = (name: string): Skill | undefined => {
  if (!skillName.test(name)) {
    return undefined;
  }
  const file = path.join(process.cwd(), 'skills', `${name}.md`);
  try {
    return {
      name,
      instructions: readFileSync(file, 'utf8').trim(),
      tools: {},
    };
  } catch (error) {
    if (isMissingFile(error)) {
      return undefined;
    }
    throw error;
  }
};

const isMissingFile = (error: unknown): error is NodeJS.ErrnoException =>
  error instanceof Error && 'code' in error && error.code === 'ENOENT';
