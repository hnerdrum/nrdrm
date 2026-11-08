import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export const getQueryString = (
  queryVal: string | string[] | undefined,
): string | undefined => {
  if (typeof queryVal === 'string') {
    return queryVal;
  }
  if (!queryVal || queryVal.length === 0) {
    return undefined;
  }
  return queryVal[0];
};
