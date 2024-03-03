import { useForm } from "react-hook-form";
import { useSWRConfig } from "swr";
import { useState } from "react";
import { RequestResult, postRequest } from "../../domain/api";

export const meApiUrl = `/api/v1/me`;

type LoginData = {
  email: string;
  password: string;
};

export const login = async (
  loginData: LoginData
): Promise<RequestResult<{ token: string }>> =>
  postRequest("/api/v1/login", loginData);

export const LoginView = () => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginData>();
  const [loginError, setLoginError] = useState(undefined);
  const { mutate } = useSWRConfig();

  const onSubmit = async (data: LoginData) => {
    const result = await login(data);

    if (result.status === "success") {
      mutate(meApiUrl);
      window.location.href = "/recipes";
    } else {
      setLoginError("Failed");
    }
  };

  return (
    <div className="flex flex-col gap-4 w-full lg:w-1/2 lg:px-0 px-8 mx-auto mt-8">
      <h1 className="text-3xl font-bold text-gray-200">Login</h1>
      <div className="w-full mx-auto">
        <form
          className="bg-gray-900 shadow-lg rounded px-8 pt-6 pb-8 mb-4"
          onSubmit={handleSubmit(onSubmit)}
        >
          <div className="mb-4">
            <label
              className="block text-gray-200 text-sm font-bold mb-2"
              htmlFor="recipeName"
            >
              Email
            </label>
            <input
              className="w-full px-2 py-2 text-gray-200 border-neutral rounded shadow-md bg-neutral appearance-none focus:outline-none focus:shadow-outline"
              id="email"
              type="text"
              {...register("email", { required: "Email is required" })}
            />
            {errors.email && (
              <p className="text-red-400 text-sm mt-2">
                {errors.email.message}
              </p>
            )}
          </div>
          <div className="mb-4">
            <label
              className="block text-gray-200 text-sm font-bold mb-2"
              htmlFor="recipeName"
            >
              Password
            </label>
            <input
              className="w-full px-2 py-2 text-gray-200 border-neutral rounded shadow-md bg-neutral appearance-none focus:outline-none focus:shadow-outline"
              id="password"
              type="password"
              {...register("password", { required: "Password is required" })}
            />
            {errors.password && (
              <p className="text-red-400 text-sm mt-2">
                {errors.password.message}
              </p>
            )}
          </div>
          <button type="submit" className="btn btn-primary">
            Login
          </button>
        </form>
      </div>
      {loginError && <p className="text-red-400 text-sm mt-2">{loginError}</p>}
    </div>
  );
};
