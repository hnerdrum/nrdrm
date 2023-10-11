import useSWR from "swr";

export type Recipe = {
  id: string;
  createdAt: Date;
  updatedAt: Date;
  name: string;
  description: string;
  ingredients: Ingredient[];
};

export type Ingredient = {
  id: string;
  createdAt: Date;
  updatedAt: Date;
  name: string;
  amount: number;
  unit: Unit;
};

export type Unit = "G" | "Ml" | "Tbsp" | "Tsp" | "Qty";

const fetcher = (arg: string): Promise<Recipe[]> =>
  fetch(arg).then((res) => res.json());

export const useRecipes = () => {
  const { data, error, isLoading } = useSWR(
    "http://localhost:8000/api/v1/recipes",
    fetcher
  );

  return { recipes: data, error, isLoading };
};
