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
  title: "مجموعة الفارس | تسليم المهام",
  description: "نظام تسليم المهام لمجموعة الفارس، مربوط بإخلاء الطرف في موارد الفارس البشرية.",
  icons: { icon: "/brand/alfaris-mark.png" },
};

export default async function RootLayout({ children }: LayoutProps<"/">) {
  const { locale, dir } = await getI18n();
  return (
    <html lang={locale} dir={dir} className={`${font.variable} h-full antialiased`}>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `(()=>{var p=performance,m=p.measure.bind(p);p.measure=function(){try{return m.apply(p,arguments)}catch(e){if(!String(e&&e.message||e).includes("negative time stamp"))throw e}}})();`,
          }}
        />
      </head>
      <body className="min-h-full flex flex-col">
        {children}
        <Toaster position="top-center" richColors />
      </body>
    </html>
  );
}
