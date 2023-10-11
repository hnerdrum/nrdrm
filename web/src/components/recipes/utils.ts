import { Ingredient, Unit } from "../../hooks/useRecipes";

export const formatIngredient = (ingredient: Ingredient) => {
  return `${ingredient.amount} ${formatUnit(ingredient.unit)} ${
    ingredient.name
  }`;
};

const formatUnit = (unit: Unit) => {
  if (unit === "Qty") return "";
  return unit.toLowerCase();
};
