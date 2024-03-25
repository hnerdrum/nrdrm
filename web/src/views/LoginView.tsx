"use client";

import { LoginForm } from "../components/login/LoginForm";

export const LoginView = () => {
  return (
    <div className="flex flex-col gap-4 w-full lg:w-1/2 lg:px-0 px-8 mx-auto mt-8">
      <h1 className="text-3xl font-bold">Login</h1>
      <LoginForm />
    </div>
  );
};
