import useSWR from "swr";
import { Recipe } from "../domain";
import { config } from "../../config";

const fetcher = (arg: string): Promise<Recipe[]> =>
  fetch(`${config.baseServerUrl}${arg}`).then((res) => res.json());

export const useIngredients = () => {
  const { data, error, isLoading } = useSWR(`/api/v1/ingredients`, fetcher);

  return { ingredients: data, error, isLoading };
};
