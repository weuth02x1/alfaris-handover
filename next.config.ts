import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // The dev server allows localhost only. The browser opens it as 127.0.0.1,
  // and Next then rejects the dev socket, so the page never hydrates and clicks do nothing.
  allowedDevOrigins: ["127.0.0.1"],
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
