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
