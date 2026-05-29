export function installViewportHeightVariable(): () => void {
  if (typeof window === 'undefined' || typeof document === 'undefined') {
    return () => undefined;
  }

  const setViewportHeight = () => {
    document.documentElement.style.setProperty('--wk-viewport-height', `${window.innerHeight}px`);
  };

  setViewportHeight();
  window.addEventListener('resize', setViewportHeight);
  window.visualViewport?.addEventListener('resize', setViewportHeight);

  return () => {
    window.removeEventListener('resize', setViewportHeight);
    window.visualViewport?.removeEventListener('resize', setViewportHeight);
  };
}
