import { NewRecipeView } from "../views/NewRecipeView";
import { RecipeForm } from "../components/recipes/RecipeForm";
import { UpdateRecipeView } from "../views/UpdateRecipeView";
import { AuthProvider } from "../providers/AuthProvider";

export const RecipePage = ({ recipeId }: { recipeId?: string }) => {
  return (
    <AuthProvider>
      <UpdateRecipeView recipeId={recipeId} />
    </AuthProvider>
  );
};
