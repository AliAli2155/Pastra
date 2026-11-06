{{flutter_js}}
{{flutter_build_config}}

// Run the app inside <div id="app"> (see index.html) instead of the whole
// page, so the iPhone safe area and the desktop phone-column are pure CSS.
_flutter.loader.load({
  config: {
    // Chrome and Edge get the WebAssembly build (see web-pages.yml). GitHub
    // Pages cannot send the headers for its multi-threaded mode, so it runs
    // on one thread: that is expected, no need to warn about it.
    suppressMultithreadingWarning: true,
  },
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
