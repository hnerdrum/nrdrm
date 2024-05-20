import { formatIngredient } from "./utils";
import { Recipe } from "../../app/domain";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "../ui/accordion";
import { Badge } from "../ui/badge";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "../ui/dropdown-menu";
import { Ellipsis } from "lucide-react";
import { useSWRConfig } from "swr";
import { deleteRecipe, recipesApiUrl } from "../../app/domain/api";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "../ui/dialog";
import { Label } from "@radix-ui/react-dropdown-menu";
import { Input } from "postcss";
import { Button } from "../ui/button";
import { useAuth } from "../../providers/AuthProvider";
import { useRouter } from "next/navigation";

type Props = {
  recipes: Recipe[];
};

export const RecipeList = ({ recipes }: Props) => {
  return (
    <Accordion type="single" collapsible className="w-full">
      {recipes.map((recipe) => (
        <RecipeItem key={recipe.id} recipe={recipe} />
      ))}
    </Accordion>
  );
};

const RecipeItem = ({ recipe }: { recipe: Recipe }) => {
  const { isLoggedIn } = useAuth();

  return (
    <AccordionItem
      value={recipe.id}
      className="shadow border border-hsla(204, 100%, 10%, 0.18) rounded-md px-8 mb-4"
    >
      <AccordionTrigger
        withChevron={false}
        className="hover:no-underline text-lg"
      >
        <div>{recipe.name}</div>
        {isLoggedIn && <RecipeMenu recipe={recipe} />}
      </AccordionTrigger>
      <AccordionContent>
        <div className="flex flex-col">
          {recipe.description}
          {!!recipe.ingredients.length && (
            <div className="flex flex-wrap gap-2 pt-4">
              {recipe.ingredients.map((ingredient) => (
                <Badge key={ingredient.id}>
                  {formatIngredient(ingredient)}
                </Badge>
              ))}
            </div>
          )}
        </div>
      </AccordionContent>
    </AccordionItem>
  );
};

const RecipeMenu = ({ recipe }: { recipe: Recipe }) => {
  return (
    <Dialog>
      <DropdownMenu>
        <DropdownMenuTrigger>
          <Ellipsis />
        </DropdownMenuTrigger>
        <DropdownMenuContent>
          <DeleteRecipeButton />
          <UpdateRecipeButton recipe={recipe} />
        </DropdownMenuContent>
      </DropdownMenu>
      <DeleteRecipeDialog recipe={recipe} />
    </Dialog>
  );
};

const DeleteRecipeButton = () => {
  return (
    <DialogTrigger asChild>
      <DropdownMenuItem className="cursor-pointer py-0">
        <Button variant="ghost">Delete recipe</Button>
      </DropdownMenuItem>
    </DialogTrigger>
  );
};

const UpdateRecipeButton = ({ recipe }: { recipe: Recipe }) => {
  const router = useRouter();
  return (
    <DropdownMenuItem className="cursor-pointer py-0">
      <Button variant="ghost" onClick={() => router.push(`/${recipe.id}`)}>
        Update recipe
      </Button>
    </DropdownMenuItem>
  );
};

const DeleteRecipeDialog = ({ recipe }: { recipe: Recipe }) => {
  const { mutate } = useSWRConfig();

  const onDeleteRecipe = async () => {
    const result = await deleteRecipe(recipe.id);
    if (result.status !== "success") {
      alert(`Recipe deletion failed with message: ${result.message}`);
      return;
    }
    mutate(recipesApiUrl);
  };

  return (
    <DialogContent className="sm:max-w-[425px]">
      <DialogHeader>
        <DialogTitle>Delete recipe</DialogTitle>
        <DialogDescription className="py-4">
          Are you sure you want to delete recipe &quot;{recipe.name}&quot;?
        </DialogDescription>
      </DialogHeader>
      <DialogFooter>
        <Button type="submit" variant="destructive" onClick={onDeleteRecipe}>
          Confirm
        </Button>
      </DialogFooter>
    </DialogContent>
  );
};
