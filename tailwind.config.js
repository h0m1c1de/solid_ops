/** @type {import('tailwindcss').Config} */
module.exports = {
  // Scope all utilities so they only apply inside .solid-ops wrapper.
  // This prevents conflicts with host app CSS.
  important: '.solid-ops',
  content: [
    "./app/views/**/*.html.erb",
    "./app/helpers/**/*.rb",
  ],
  corePlugins: {
    // Disable Tailwind's global reset (Preflight) so we don't
    // clobber the host app's base styles.
    preflight: false,
  },
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        mono: ['ui-monospace', 'SFMono-Regular', 'Menlo', 'Monaco', 'Consolas', 'monospace'],
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
  ],
}
