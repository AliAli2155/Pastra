{{flutter_js}}
{{flutter_build_config}}

// Run the app inside <div id="app"> (see index.html) instead of the whole
// page, so the iPhone safe area and the desktop phone-column are pure CSS.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: document.querySelector('#app'),
    });
    await appRunner.runApp();
    const loading = document.getElementById('loading');
    if (loading) {
      loading.style.opacity = '0';
      setTimeout(function () { loading.remove(); }, 400);
    }
  },
});
