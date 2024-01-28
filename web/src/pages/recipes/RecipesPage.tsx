import { RecipesView } from "../../components/recipes/RecipesView";
import { AuthProvider } from "../../providers/AuthProvider";

export const RecipesPage = () => {
  return (
    <AuthProvider>
      <RecipesView />
    </AuthProvider>
  );
};
