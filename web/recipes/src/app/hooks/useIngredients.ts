import useSWR from "swr";
import { config } from "../../../config";
import { Ingredient } from "../domain";
import { IngredientApi } from "../api/ingredient";

const fetcher = (arg: string): Promise<Ingredient[]> =>
  fetch(`${config.baseServerUrl}${arg}`).then((res) => res.json());

export const useIngredients = () => {
  const { data, error, isLoading } = useSWR(IngredientApi.baseUrl, fetcher);

  return { ingredients: data, error, isLoading };
};
