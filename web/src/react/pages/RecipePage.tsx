import { UpdateRecipeView } from "../views/UpdateRecipeView";
import { AuthProvider } from "../providers/AuthProvider";

export const RecipePage = ({ recipeId }: { recipeId?: string }) => {
  return (
    <AuthProvider>
      <UpdateRecipeView recipeId={recipeId} />
    </AuthProvider>
  );
};
