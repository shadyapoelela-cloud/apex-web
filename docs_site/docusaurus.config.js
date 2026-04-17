// @ts-check
// Scaffold for docs.apex.sa — APEX developer documentation site.
//
// After `npm install && npm start` this serves at http://localhost:3000.
// Production build: `npm run build` → output in `build/`, deploy to Pages.

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'APEX Developer Docs',
  tagline: 'Build on the Middle East\'s AI-native financial platform',
  url: 'https://docs.apex-app.com',
  baseUrl: '/',
  favicon: 'img/favicon.png',

  organizationName: 'apex',
  projectName: 'apex-docs',

  i18n: {
    defaultLocale: 'ar',
    locales: ['ar', 'en'],
    localeConfigs: {
      ar: { label: 'العربية', direction: 'rtl' },
      en: { label: 'English', direction: 'ltr' },
    },
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/apex/apex-web/tree/main/docs_site/',
        },
        blog: false,
        theme: { customCss: require.resolve('./src/css/custom.css') },
      }),
    ],
  ],

  themeConfig: /** @type {import('@docusaurus/preset-classic').ThemeConfig} */ ({
    navbar: {
      title: 'APEX',
      logo: { alt: 'APEX', src: 'img/logo.svg' },
      items: [
        { type: 'doc', docId: 'getting-started', position: 'left', label: 'البدء' },
        { type: 'doc', docId: 'api/overview', position: 'left', label: 'API' },
        { type: 'doc', docId: 'sdks/python', position: 'left', label: 'SDKs' },
        { type: 'doc', docId: 'webhooks', position: 'left', label: 'Webhooks' },
        { type: 'localeDropdown', position: 'right' },
        { href: 'https://github.com/apex/apex-web', label: 'GitHub', position: 'right' },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'منصة APEX',
          items: [
            { label: 'الموقع', href: 'https://apex-app.com' },
            { label: 'الحالة', href: 'https://status.apex-app.com' },
          ],
        },
        {
          title: 'المطورون',
          items: [
            { label: 'API Reference', to: '/docs/api/overview' },
            { label: 'SDKs', to: '/docs/sdks/python' },
            { label: 'Webhooks', to: '/docs/webhooks' },
            { label: 'Postman Collection', href: '/apex.postman_collection.json' },
          ],
        },
        {
          title: 'الدعم',
          items: [
            { label: 'تذكرة دعم', href: 'https://apex-app.com/support' },
            { label: 'Discord', href: 'https://discord.gg/apex' },
          ],
        },
      ],
      copyright: `© ${new Date().getFullYear()} APEX Financial Platform`,
    },
    prism: { theme: require('prism-react-renderer').themes.nightOwl },
  }),
};

module.exports = config;
