import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { useState } from "react";
import { useSWRConfig } from "swr";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "../ui/form";
import { Button } from "../ui/button";
import { Input } from "../ui/input";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { IdentityApi } from "../../api/identity";

const loginSchema = z.object({
  email: z.string().min(1, {
    message: "Email is required.",
  }),
  password: z.string().min(1, {
    message: "Password is required.",
  }),
});

type LoginData = z.infer<typeof loginSchema>;

export const LoginForm = () => {
  const router = useRouter();
  const form = useForm<LoginData>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      email: "",
      password: "",
    },
  });
  const [loginError, setLoginError] = useState<string | undefined>(undefined);
  const { mutate } = useSWRConfig();

  const onSubmit = async (data: LoginData) => {
    const result = await IdentityApi.login(data);

    if (result.status === "success") {
      mutate(`${IdentityApi.baseUrl}/me`);
      router.push(`/`);
    } else {
      setLoginError("Failed");
    }
  };

  return (
    <Form {...form}>
      <form
        onSubmit={form.handleSubmit(onSubmit)}
        className="flex flex-col shadow border border-hsla(204, 100%, 10%, 0.18) rounded-md px-8 pt-6 pb-8 mb-4 space-y-6 w-full mx-auto"
      >
        <FormField
          control={form.control}
          name="email"
          render={({ field }) => (
            <FormItem>
              <FormLabel htmlFor="email">Email</FormLabel>
              <FormControl>
                <Input id="email" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <FormField
          control={form.control}
          name="password"
          render={({ field }) => (
            <FormItem>
              <FormLabel htmlFor="password">Password</FormLabel>
              <FormControl>
                <Input id="password" type="password" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button type="submit">Login</Button>
      </form>
      {loginError && <p className="text-destructive font-bold">{loginError}</p>}
    </Form>
  );
};
