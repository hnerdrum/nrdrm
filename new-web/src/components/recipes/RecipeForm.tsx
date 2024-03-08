"use client";

import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import type { ControllerProps, FieldPath, FieldValues } from "react-hook-form";
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

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
  onSubmit,
}: {
  onSubmit: (data: CreateRecipeFormData) => Promise<void>;
}) => {
  const form = useForm<CreateRecipeFormData>({
    resolver: zodResolver(createRecipeSchema),
    defaultValues: {
      name: "",
      description: "",
    },
  });

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8">
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
        <Button type="submit">Submit</Button>
      </form>
    </Form>
  );
};
