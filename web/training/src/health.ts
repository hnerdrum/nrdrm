export type Health = {
  status: string;
};

export async function loadHealth(): Promise<Health> {
  const response = await fetch('/training/health', { credentials: 'include' });
  if (!response.ok) {
    throw new Error('health check failed');
  }
  return response.json() as Promise<Health>;
}
