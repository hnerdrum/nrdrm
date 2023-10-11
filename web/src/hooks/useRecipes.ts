import useSWR from "swr";
import { Recipe } from "../domain";

const fetcher = (arg: string): Promise<Recipe[]> =>
  fetch(arg).then((res) => res.json());

export const useRecipes = () => {
  const { data, error, isLoading } = useSWR(
    "http://localhost:8000/api/v1/recipes",
    fetcher
  );

  return { recipes: data, error, isLoading };
};
