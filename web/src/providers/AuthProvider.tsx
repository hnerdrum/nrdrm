import { createContext, useContext, useMemo } from "react";
import { config } from "../../config";
import { UserSettings } from "../app/domain";
import useSWR from "swr";

export const meApiUrl = `/recipes/me`;

type AuthData = {
  isLoggedIn: boolean;
  isLoading: boolean;
};

const fetcher = (arg: string): Promise<UserSettings> =>
  fetch(`${config.baseServerUrl}${arg}`, {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
    },
    credentials: "include",
  }).then((res) => res.json());

const defaultData: AuthData = {
  isLoggedIn: false,
  isLoading: false,
};

export const AuthContext = createContext<AuthData>(defaultData);

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const { data, isLoading } = useSWR(meApiUrl, fetcher);

  const AuthProviderValue = useMemo(
    () => ({
      isLoggedIn: !!data?.auth?.userId,
      isLoading,
    }),
    [data?.auth?.userId, isLoading]
  );

  return (
    <AuthContext.Provider value={AuthProviderValue}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = (): AuthData => {
  return useContext(AuthContext);
};
