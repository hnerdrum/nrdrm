import type { SessionBody } from '../domain';

import { ApiError, request } from './client';

/** A named session body with no date, kept to start new sessions from. */
export type Preset = {
  id: string;
  name: string;
  body: SessionBody;
};

export const presetsQueryKey = ['presets'] as const;

export function listPresets(): Promise<Preset[]> {
  return request('/training/presets');
}

export function createPreset(name: string, body: SessionBody): Promise<Preset> {
  return request('/training/presets', {
    method: 'POST',
    body: { name, body },
  });
}

export function updatePreset(
  id: string,
  name: string,
  body: SessionBody,
): Promise<Preset> {
  return request(`/training/presets/${id}`, {
    method: 'PUT',
    body: { name, body },
  });
}

export async function deletePreset(id: string): Promise<void> {
  await request(`/training/presets/${id}`, { method: 'DELETE' });
}

/** Another preset already has that name, regardless of case. */
export function isNameTaken(error: unknown): boolean {
  return error instanceof ApiError && error.status === 409;
}
