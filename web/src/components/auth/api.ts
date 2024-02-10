import { PostRequestResult, postRequest } from "../recipes/api";

export const meApiUrl = `/api/v1/me`;

type LoginData = {
  email: string;
  password: string;
};

export const login = async (
  loginData: LoginData
): Promise<PostRequestResult<{ token: string }>> =>
  postRequest("/api/v1/login", loginData);
