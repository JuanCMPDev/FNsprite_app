import type { Metadata } from "next";

import "./globals.css";

export const metadata: Metadata = {
  description: "Open-source trading board foundation for Fortnite spirit exchanges.",
  title: "SpiritMatch",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
