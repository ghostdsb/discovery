const colors = require('tailwindcss/colors')

module.exports = {
  purge: [
    '../lib/**/*.ex',
    '../lib/**/*.leex',
    '../lib/**/*.heex',
    '../lib/**/*.eex',
    './js/**/*.js'
  ],
  darkMode: 'class', // or 'media' or 'class'
  theme: {
    extend: {
      colors: {
        slate: colors.blueGray,
        zinc: colors.coolGray,
        emerald: colors.emerald,
      }
    },
  },
  variants: {
    extend: {},
  },
  plugins: [],
}
