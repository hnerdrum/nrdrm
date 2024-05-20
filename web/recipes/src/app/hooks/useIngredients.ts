import useSWR from "swr";
import { config } from "../../../config";
import { Ingredient } from "../domain";
import { ingredientsApiUrl } from "../domain/api";

const fetcher = (arg: string): Promise<Ingredient[]> =>
  fetch(`${config.baseServerUrl}${arg}`).then((res) => res.json());

export const useIngredients = () => {
  const { data, error, isLoading } = useSWR(ingredientsApiUrl, fetcher);

  return { ingredients: data, error, isLoading };
};
