import { RecipeIngredient, Unit } from "../../domain";

export const formatIngredient = (ingredient: RecipeIngredient) => {
  return `${ingredient.amount} ${formatUnit(ingredient.unit)} ${
    ingredient.name
  }`;
};

const formatUnit = (unit: Unit) => {
  if (unit.toLowerCase() === Unit.Qty) return "";
  return unit.toLowerCase();
};
