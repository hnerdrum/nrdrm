import useSWR from "swr";
import type { Recipe } from "../../domain";
import { config } from "../../../config";
import { recipesApiUrl } from "../../domain/api";

const fetcher = (arg: string): Promise<Recipe> =>
  fetch(`${config.baseServerUrl}${arg}`).then((res) => res.json());

export const useRecipe = ({ recipeId }: { recipeId: string }) => {
  const { data, error, isLoading } = useSWR(
    `${recipesApiUrl}/${recipeId}`,
    fetcher
  );

  return { recipe: data, error, isLoading };
};
