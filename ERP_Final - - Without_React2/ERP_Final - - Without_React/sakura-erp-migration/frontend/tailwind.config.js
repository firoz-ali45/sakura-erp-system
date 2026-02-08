/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Cairo', 'sans-serif'],
      },
      colors: {
        sakura: {
          primary: '#284b44',
          secondary: '#3d6b5f',
          accent: '#6366f1',
          background: '#f0e1cd',
        }
      }
    },
  },
  plugins: [],
}

