export type Recipe = {
  id: string;
  name: string;
  description: string | null;
  ingredients: RecipeIngredient[];
};

export type RecipeIngredient = {
  id: string;
  name: string;
  amount: number;
  unit: Unit;
};

export const Unit = {
  G: "g",
  Ml: "ml",
  Tbsp: "tbsp",
  Tsp: "tsp",
  Qty: "qty",
} as const;

export type Unit = (typeof Unit)[keyof typeof Unit];

export type Ingredient = {
  id: string;
  name: string;
};

export type User = {
  id: string;
  email: string;
};

export type UserSettings = {
  auth: Auth | null;
};

export type Auth = { userId: string; tokenId: string; email: string };
