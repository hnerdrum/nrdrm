import { createContext, useContext, useMemo } from "react";
import { config } from "../../config";
import { Auth, UserSettings } from "../domain";
import useSWR from "swr";
import { meApiUrl } from "../components/auth/api";

type AuthData = {
  isLoggedIn: boolean;
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
};

export const AuthContext = createContext<AuthData>(defaultData);

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const { data } = useSWR(meApiUrl, fetcher);

  const AuthProviderValue = useMemo(
    () => ({
      isLoggedIn: !!data?.auth?.userId,
    }),
    [data]
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
