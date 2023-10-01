import { useRecipes } from "../../hooks/useRecipes";

export const RecipesView = () => {
  const { recipes, isLoading, error } = useRecipes();

  if (isLoading || error) {
    return null;
  }

  return (
    <div className="flex flex-col gap-4 w-1/4 mx-auto">
      <h1 className="text-3xl font-bold text-gray-400 mt-8">Recipes</h1>
      {recipes.map((recipe) => (
        <div className="collapse collapse-arrow border border-base-300 bg-base-200">
          <input type="checkbox" />
          <div className="collapse-title text-l font-medium">{recipe.name}</div>
          <div className="collapse-content">{recipe.description}</div>
        </div>
      ))}
    </div>
  );
};
