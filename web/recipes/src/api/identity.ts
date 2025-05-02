import { postRequest } from ".";
import { User } from "../domain";

export type LoginData = {
  email: string;
  password: string;
};

const baseUrl = `/identity`;

export const IdentityApi = {
  baseUrl,

  login: async (data: LoginData) =>
    postRequest<LoginData, User>(`${baseUrl}/login`, data),
};
