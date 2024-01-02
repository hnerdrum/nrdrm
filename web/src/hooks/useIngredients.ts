import useSWR from "swr";
import { Ingredient } from "../domain";
import { config } from "../../config";

const fetcher = (arg: string): Promise<Ingredient[]> =>
  fetch(`${config.baseServerUrl}${arg}`).then((res) => res.json());

export const useIngredients = () => {
  const { data, error, isLoading } = useSWR(`/api/v1/ingredients`, fetcher);

  return { ingredients: data, error, isLoading };
};
