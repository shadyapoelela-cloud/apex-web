// Docusaurus sidebar definition for docs.apex.sa

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  mainSidebar: [
    'getting-started',
    {
      type: 'category',
      label: 'REST API',
      items: [
        'api/overview',
      ],
    },
    {
      type: 'category',
      label: 'SDKs',
      items: [
        'sdks/python',
        'sdks/nodejs',
        'sdks/php',
      ],
    },
    'webhooks',
    {
      type: 'category',
      label: 'Compliance',
      items: [
        'compliance/zatca',
        'compliance/uae-fta',
      ],
    },
  ],
};

module.exports = sidebars;
