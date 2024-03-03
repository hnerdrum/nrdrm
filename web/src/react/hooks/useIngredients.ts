import useSWR from "swr";
import { config } from "../../../config";
import type { Ingredient } from "../../domain";

const fetcher = (arg: string): Promise<Ingredient[]> =>
  fetch(`${config.baseServerUrl}${arg}`).then((res) => res.json());

export const useIngredients = () => {
  const { data, error, isLoading } = useSWR(`/api/v1/ingredients`, fetcher);

  return { ingredients: data, error, isLoading };
};
