'use client';

import { Roboto_Mono } from 'next/font/google';

import './globals.css';
import { AuthProvider } from '../providers/AuthProvider';

const robotoMono = Roboto_Mono({ subsets: ['latin'] });

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={robotoMono.className}>
        <AuthProvider>{children}</AuthProvider>
      </body>
    </html>
  );
}
