import { RecipesView } from "../views/RecipesView";
import { AuthProvider } from "../providers/AuthProvider";

export const RecipesPage = () => {
  return (
    <AuthProvider>
      <RecipesView />
    </AuthProvider>
  );
};
