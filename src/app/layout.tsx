import type { Metadata } from "next";
import { IBM_Plex_Sans_Arabic } from "next/font/google";
import { Toaster } from "@/components/ui/sonner";
import { getI18n } from "@/lib/i18n/server";
import "./globals.css";

const font = IBM_Plex_Sans_Arabic({
  variable: "--font-app",
  subsets: ["arabic", "latin"],
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: "نظام تسليم المهام | Employee Handover",
  description: "Employee handover receipt automation for vacation and termination clearance.",
};

export default async function RootLayout({ children }: LayoutProps<"/">) {
  const { locale, dir } = await getI18n();
  return (
    <html lang={locale} dir={dir} className={`${font.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col">
        {children}
        <Toaster position="top-center" richColors />
      </body>
    </html>
  );
}
