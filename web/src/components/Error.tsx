export const Error = ({ text }: { text: string }) => {
  return (
    <div className="min-h-screen flex items-center justify-center">
      <h1 className="text-red-500 font-bold">{text}</h1>
    </div>
  );
};
