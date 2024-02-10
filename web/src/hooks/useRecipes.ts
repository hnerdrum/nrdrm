import useSWR from "swr";
import { Recipe } from "../domain";
import { config } from "../../config";
import { recipesApiUrl } from "../components/recipes/api";

const fetcher = (arg: string): Promise<Recipe[]> =>
  fetch(`${config.baseServerUrl}${arg}`).then((res) => res.json());

export const useRecipes = () => {
  const { data, error, isLoading } = useSWR(recipesApiUrl, fetcher);

  return { recipes: data, error, isLoading };
};
