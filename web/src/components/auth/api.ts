import { RequestResult, postRequest } from "../recipes/api";

export const meApiUrl = `/api/v1/me`;

type LoginData = {
  email: string;
  password: string;
};

export const login = async (
  loginData: LoginData
): Promise<RequestResult<{ token: string }>> =>
  postRequest("/api/v1/login", loginData);
