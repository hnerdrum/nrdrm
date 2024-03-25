import { Roboto_Mono } from "next/font/google";

const robotoMono = Roboto_Mono({ subsets: ["latin"] });

export default function Home() {
  return (
    <main
      className={`w-screen h-screen bg-custom-background ${robotoMono.className}`}
    >
      <h1 className="text-2xl font-bold pt-40 pl-80 text-custom-primary">
        I&apos;m a software engineer
      </h1>
    </main>
  );
}
