import useSWR from 'swr';

import { config } from '../../config';
import { RecipeApi } from '../api/recipe';
import type { Recipe } from '../domain';

const fetcher = (arg: string): Promise<Recipe> =>
  fetch(`${config.baseServerUrl}${arg}`).then((res) => res.json());

export const useRecipe = ({ recipeId }: { recipeId: string }) => {
  const { data, error, isLoading } = useSWR(
    `${RecipeApi.baseUrl}/${recipeId}`,
    fetcher,
  );

  return { recipe: data, error, isLoading };
};
