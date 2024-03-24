import { useRouter } from "next/router";
import { UpdateRecipeView } from "../../../components/recipes/UpdateRecipeView";
import { Error404 } from "../../../components/ui/404";
import { getQueryString } from "../../../lib/utils";

const UpdateRecipePage = ({ params }: { params: { recipeId: string } }) => {
  return <UpdateRecipeView recipeId={params.recipeId} />;
};

export default UpdateRecipePage;
