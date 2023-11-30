import useSWR from "swr";
import { Recipe } from "../domain";
import { config } from "../../config";

const fetcher = (arg: string): Promise<Recipe[]> =>
  fetch(`${config.baseServerUrl}${arg}`).then((res) => res.json());

export const useRecipes = () => {
  const { data, error, isLoading } = useSWR(`/api/v1/recipes`, fetcher);

  return { recipes: data, error, isLoading };
};
