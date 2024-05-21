"use client";

import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Check, ChevronsUpDown } from "lucide-react";
import { useState } from "react";
import React from "react";
import { useIngredients } from "../../app/hooks/useIngredients";
import { useSWRConfig } from "swr";
import { Label } from "../ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "../ui/select";
import { Recipe, RecipeIngredient, Unit } from "../../app/domain";
import { unitFromString } from "../../app/domain/utils";
import { formatIngredient } from "./utils";
import { Badge } from "../ui/badge";
import { IngredientApi } from "../../app/api/ingredient";

const createRecipeSchema = z.object({
  name: z.string().min(1, {
    message: "Recipe name is required.",
  }),
  description: z.string().min(1, {
    message: "Recipe description is required.",
  }),
});

export type CreateRecipeFormData = z.infer<typeof createRecipeSchema>;

export const RecipeForm = ({
  recipe,
  onSubmit,
}: {
  recipe?: Recipe;
  onSubmit: (
    data: CreateRecipeFormData & { ingredients: RecipeIngredient[] }
  ) => Promise<void>;
}) => {
  const { mutate } = useSWRConfig();

  const form = useForm<CreateRecipeFormData>({
    resolver: zodResolver(createRecipeSchema),
    defaultValues: {
      name: recipe?.name ?? "",
      description: recipe?.description ?? "",
    },
  });

  const { ingredients } = useIngredients();

  const [recipeIngredients, setRecipeIngredients] = useState<
    RecipeIngredient[]
  >(recipe?.ingredients ?? []);
  const [selectedIngredient, setSelectedIngredient] = useState<{
    value: string;
    label: string;
  } | null>(null);
  const [selectedAmount, setSelectedAmount] = useState<number | "">("");
  const [selectedUnit, setSelectedUnit] = useState<Unit | "">("");
  const [showIngredientError, setShowIngredientError] = useState(false);

  const selectIngredient = (ingredient: { value: string; label: string }) => {
    setSelectedIngredient(ingredient);
  };

  const onSubmitForm = (data: CreateRecipeFormData) =>
    onSubmit({ ...data, ingredients: recipeIngredients });

  const onCreateNewIngredient = async (name: string) => {
    const result = await IngredientApi.create({ name });
    if (result.status === "success") {
      mutate(IngredientApi.baseUrl);
      result.data &&
        selectIngredient({ value: result.data.id, label: result.data.name });
    } else {
      alert(`Ingredient creation failed with message: ${result.message}`);
    }
  };

  const handleAddIngredient = (e: React.FormEvent) => {
    e.preventDefault();
    setShowIngredientError(false);

    if (!selectedIngredient || !selectedAmount || !selectedUnit) {
      setShowIngredientError(true);
      return;
    }

    setRecipeIngredients((recipeIngredients) => [
      ...recipeIngredients.filter((ri) => ri.id !== selectedIngredient.label),
      {
        id: selectedIngredient.value,
        name: selectedIngredient.label,
        amount: selectedAmount,
        unit: selectedUnit,
      },
    ]);

    resetIngredientForm();
  };

  const handleRemoveIngredient = (ingredient: RecipeIngredient) => {
    setRecipeIngredients(
      recipeIngredients.filter((ri) => ri.id !== ingredient.id)
    );
  };

  const resetIngredientForm = () => {
    setSelectedIngredient((_) => null);
    setSelectedAmount((_) => "");
    setSelectedUnit((_) => "");
  };

  const handleAmountInputChange = (value: string) => {
    if (value === "") {
      return;
    }
    setSelectedAmount(parseFloat(value));
  };

  return (
    <Form {...form}>
      <form
        onSubmit={form.handleSubmit(onSubmitForm)}
        className="flex flex-col shadow border border-hsla(204, 100%, 10%, 0.18) rounded-md px-8 pt-6 pb-8 mb-4 space-y-6 w-full mx-auto"
      >
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel htmlFor="recipe-name">Recipe name</FormLabel>
              <FormControl>
                <Input id="recipe-name" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <FormField
          control={form.control}
          name="description"
          render={({ field }) => (
            <FormItem>
              <FormLabel htmlFor="recipe-description">
                Recipe description
              </FormLabel>
              <FormControl>
                <Input id="recipe-description" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <div>
          <div className="flex space-x-2">
            <div className="flex-1 flex-col space-y-2">
              <Label>Ingredient name</Label>
              <ComboboxDemo
                options={(ingredients || []).map((i) => ({
                  label: i.name,
                  value: i.id,
                }))}
                selected={selectedIngredient}
                onOptionClick={selectIngredient}
                onOptionCreate={onCreateNewIngredient}
              />
            </div>
            <div className="flex-1 flex-col space-y-2">
              <Label>Ingredient amount</Label>
              <Input
                type="number"
                min={0}
                value={selectedAmount}
                onChange={(e) => handleAmountInputChange(e.target.value)}
              />
            </div>
            <div className="flex-1 flex-col space-y-2">
              <Label>Ingredient unit</Label>
              <Select
                value={selectedUnit}
                onValueChange={(value) =>
                  setSelectedUnit(unitFromString(value))
                }
              >
                <SelectTrigger className="flex-grow">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="G">g</SelectItem>
                  <SelectItem value="Ml">ml</SelectItem>
                  <SelectItem value="Tbsp">tbsp</SelectItem>
                  <SelectItem value="Tsp">tsp</SelectItem>
                  <SelectItem value="Qty">qty</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="flex flex-col justify-end min-w-16">
              <Button onClick={handleAddIngredient}>Add</Button>
            </div>
          </div>
          {showIngredientError && (
            <p className="text-destructive text-sm mt-2">
              You must specify ingredient name, amount and unit to add it to the
              recipe
            </p>
          )}
          <div className="flex flex-wrap gap-2 px-2 pb-2 mt-4">
            {recipeIngredients.map((ingredient) => (
              <Badge
                key={ingredient.id}
                onClick={() => handleRemoveIngredient(ingredient)}
                className="cursor-pointer text-xs"
              >
                {formatIngredient(ingredient)}
              </Badge>
            ))}
          </div>
        </div>
        <Button type="submit">Submit</Button>
      </form>
    </Form>
  );
};

type ComboboxProps<T extends { label: string; value: string }> = {
  options: T[];
  placeholder?: string;
  selected: { value: string; label: string } | null;
  onOptionClick(option: { value: string; label: string }): void;
  onOptionCreate(label: string): void;
};

export const ComboboxDemo = <T extends { label: string; value: string }>({
  options,
  selected,
  onOptionClick,
  onOptionCreate,
}: ComboboxProps<T>) => {
  const [open, setOpen] = React.useState(false);
  const [inputValue, setInputValue] = useState("");

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          role="combobox"
          aria-expanded={open}
          className="w-full justify-between"
        >
          {selected
            ? options.find((option) => option.value === selected.value)?.label
            : "Select ingredient..."}
          <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-[200px] p-0">
        <Command>
          <CommandInput
            value={inputValue}
            onValueChange={setInputValue}
            placeholder="Search ingredients..."
          />
          <CommandEmpty>
            {inputValue && (
              <span
                className="cursor-pointer p-4"
                onClick={() => {
                  onOptionCreate(inputValue);
                  setOpen(false);
                }}
              >
                Click to create &quot;{inputValue}&quot;
              </span>
            )}
            {!inputValue && <span>No ingredients found.</span>}
          </CommandEmpty>
          <CommandList>
            <CommandGroup>
              {options.map((option) => (
                <CommandItem
                  key={option.value}
                  value={option.value}
                  onSelect={() => {
                    onOptionClick(option);
                    setOpen(false);
                  }}
                >
                  <Check
                    className={cn(
                      "mr-2 h-4 w-4",
                      selected?.value === option.value
                        ? "opacity-100"
                        : "opacity-0"
                    )}
                  />
                  {option.label}
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
};
