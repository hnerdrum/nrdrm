import useSWR from 'swr';

import { config } from '../../config';
import { RecipeApi } from '../api/recipe';
import type { Recipe } from '../domain';

const fetcher = (arg: string): Promise<Recipe[]> =>
  fetch(`${config.baseServerUrl}${arg}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
  }).then((res) => res.json());

export const useRecipes = () => {
  const { data, error, isLoading } = useSWR(RecipeApi.baseUrl, fetcher);

  return { recipes: data, error, isLoading };
};
