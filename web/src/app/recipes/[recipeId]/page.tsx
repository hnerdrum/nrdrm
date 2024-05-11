import { UpdateRecipeView } from "../../../views/UpdateRecipeView";

const UpdateRecipePage = ({ params }: { params: { recipeId: string } }) => {
  return <UpdateRecipeView recipeId={params.recipeId} />;
};

export default UpdateRecipePage;
