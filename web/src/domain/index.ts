export type Recipe = {
  id: string;
  name: string;
  description: string;
  ingredients: RecipeIngredient[];
};

export type RecipeIngredient = {
  id: string;
  name: string;
  amount: number;
  unit: Unit;
};

export type Unit = "G" | "Ml" | "Tbsp" | "Tsp" | "Qty";

export type Ingredient = {
  id: string;
  name: string;
};
