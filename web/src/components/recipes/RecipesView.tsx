import { useRecipes } from "../../hooks/useRecipes";
import { formatIngredient } from "./utils";

export const RecipesView = () => {
  const { recipes, isLoading, error } = useRecipes();

  if (isLoading || error) {
    return null;
  }

  return (
    <div className="flex flex-col gap-4 w-1/3 mx-auto">
      <h1 className="text-3xl font-bold text-gray-200 mt-8">Recipes</h1>
      {recipes.map((recipe) => (
        <div
          key={recipe.id}
          className="collapse collapse-arrow border border-base-300 bg-base-200"
        >
          <input type="checkbox" />
          <div className="collapse-title text-xl text-gray-200 font-medium">
            {recipe.name}
          </div>
          <div className="collapse-content">
            <p className="mb-4 text-gray-300">{recipe.description}</p>
            <div className="flex gap-2">
              {recipe.ingredients.map((ingredient) => (
                <div className="badge badge-primary">
                  {formatIngredient(ingredient)}
                </div>
              ))}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};
