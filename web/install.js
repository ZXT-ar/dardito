let darditoDeferredInstallPrompt = null;

window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  darditoDeferredInstallPrompt = event;
  window.dispatchEvent(new CustomEvent('dardito-install-ready'));
});

window.addEventListener('appinstalled', () => {
  darditoDeferredInstallPrompt = null;
  window.dispatchEvent(new CustomEvent('dardito-installed'));
});

window.darditoPlatform = () => {
  const ua = navigator.userAgent || '';
  const platform = navigator.platform || '';
  const touchMac = platform === 'MacIntel' && navigator.maxTouchPoints > 1;
  if (/android/i.test(ua)) return 'android';
  if (/iPad|iPhone|iPod/.test(ua) || touchMac) return 'ios';
  if (/Win/i.test(platform) || /Windows/i.test(ua)) return 'windows';
  if (/Mac/i.test(platform) || /Macintosh/i.test(ua)) return 'macos';
  return 'other';
};

window.darditoCanInstall = () => darditoDeferredInstallPrompt !== null;

window.darditoIsStandalone = () =>
  window.matchMedia('(display-mode: standalone)').matches ||
  window.navigator.standalone === true;

window.darditoInstallPwa = async () => {
  if (!darditoDeferredInstallPrompt) return 'unavailable';
  darditoDeferredInstallPrompt.prompt();
  const choice = await darditoDeferredInstallPrompt.userChoice;
  if (choice.outcome === 'accepted') darditoDeferredInstallPrompt = null;
  return choice.outcome;
};
