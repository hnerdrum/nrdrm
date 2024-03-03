import { NewRecipeView } from "../../components/recipes/NewRecipeView";
import { RecipeForm } from "../../components/recipes/RecipeForm";
import { UpdateRecipeView } from "../../components/recipes/UpdateRecipeView";
import { AuthProvider } from "../../providers/AuthProvider";

export const RecipePage = ({ recipeId }: { recipeId?: string }) => {
  return (
    <AuthProvider>
      <UpdateRecipeView recipeId={recipeId} />
    </AuthProvider>
  );
};
