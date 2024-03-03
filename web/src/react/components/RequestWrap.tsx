import { LoadingWrap } from "./LoadingWrap";

type Status = "loading" | "error" | "empty" | "success";

const getStatus = ({
  isError,
  isEmpty,
  isLoading,
}: {
  isError: boolean;
  isEmpty: boolean;
  isLoading: boolean;
}): Status => {
  if (isError) return "error";
  if (isLoading) return "loading";
  if (isEmpty) return "empty";
  return "success";
};

type Props = {
  isLoading?: boolean;
  isError?: boolean;
  isEmpty?: boolean;
  loadingComponent?: React.ReactNode;
  errorComponent?: React.ReactNode;
  emptyComponent?: React.ReactNode;
  children?: React.ReactNode;
};

export const RequestWrap = ({
  isLoading = false,
  isError = false,
  isEmpty = false,
  errorComponent,
  emptyComponent,
  children,
}: Props) => {
  const status = getStatus({ isError, isEmpty, isLoading });

  return (
    <LoadingWrap isLoading={isLoading}>
      {status === "error" && (errorComponent || <div>Error</div>)}
      {status === "empty" && (emptyComponent || <div>Empty </div>)}
      {status === "success" && children}
    </LoadingWrap>
  );
};
