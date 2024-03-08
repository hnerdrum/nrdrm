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

export const Unit = {
  G: "G",
  Ml: "Ml",
  Tbsp: "Tbsp",
  Tsp: "Tsp",
  Qty: "Qty",
} as const;

export type Unit = (typeof Unit)[keyof typeof Unit];

export type Ingredient = {
  id: string;
  name: string;
};

export type UserSettings = {
  auth: Auth | null;
};

export type Auth = { userId: string };
