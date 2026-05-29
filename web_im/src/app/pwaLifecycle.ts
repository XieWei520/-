export interface PwaLifecycleHandlers {
  onVisible?: () => void;
  onHidden?: () => void;
  onOnline?: () => void;
  onOffline?: () => void;
}

type IosNavigator = Navigator & {
  standalone?: boolean;
};

export function isStandalonePwa(): boolean {
  if (typeof window === 'undefined' || typeof navigator === 'undefined') {
    return false;
  }

  const displayModeStandalone = typeof window.matchMedia === 'function' && window.matchMedia('(display-mode: standalone)').matches;
  const iosStandalone = (navigator as IosNavigator).standalone === true;

  return displayModeStandalone || iosStandalone;
}

export function installPwaLifecycle(handlers: PwaLifecycleHandlers): () => void {
  if (typeof window === 'undefined' || typeof document === 'undefined') {
    return () => undefined;
  }

  const handleVisibilityChange = () => {
    if (document.visibilityState === 'visible') {
      handlers.onVisible?.();
    } else if (document.visibilityState === 'hidden') {
      handlers.onHidden?.();
    }
  };
  const handlePageShow = () => handlers.onVisible?.();
  const handlePageHide = () => handlers.onHidden?.();
  const handleOnline = () => handlers.onOnline?.();
  const handleOffline = () => handlers.onOffline?.();

  document.addEventListener('visibilitychange', handleVisibilityChange);
  window.addEventListener('pageshow', handlePageShow);
  window.addEventListener('pagehide', handlePageHide);
  window.addEventListener('online', handleOnline);
  window.addEventListener('offline', handleOffline);

  return () => {
    document.removeEventListener('visibilitychange', handleVisibilityChange);
    window.removeEventListener('pageshow', handlePageShow);
    window.removeEventListener('pagehide', handlePageHide);
    window.removeEventListener('online', handleOnline);
    window.removeEventListener('offline', handleOffline);
  };
}
