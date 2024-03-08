import { Loading } from "./loading";

export const LoadingWrap = ({
  isLoading,
  children,
}: {
  isLoading: boolean;
  children: React.ReactNode;
}) => {
  return (
    <>
      {isLoading && <Loading />}
      {!isLoading && children}
    </>
  );
};
