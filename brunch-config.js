exports.config = {
  files: {
    stylesheets: { joinTo: "css/app.css" }
  },

  conventions: {
    // This option sets where we should place non-css and non-js assets in.
    // By default, we set this to "/web/static/assets". Files in this directory
    // will be copied to `paths.public`, which is "priv/static" by default.
    assets: /^(web\/static\/assets)/
  },

  // Phoenix paths configuration
  paths: {
    // Dependencies and current project directories to watch
    watched: [
      "web/static",
      "test/static"
    ],

    // Where to compile files to
    public: "priv/static"
  },

  // Configure your plugins
    plugins: {
        postcss: {
            processors: [
                require('autoprefixer')(['last 4 versions'])
            ]
        }
  },

  modules: {
  },

  npm: {
    enabled: true
  }
};
