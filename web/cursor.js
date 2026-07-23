(() => {
  const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');

  const initialize = () => {
    const cursor = document.getElementById('dardito-cursor');
    if (!cursor || !finePointer.matches) return;

    window.addEventListener('pointermove', (event) => {
      if (event.pointerType && event.pointerType !== 'mouse') return;
      cursor.style.opacity = '1';
      cursor.style.transform = `translate3d(${event.clientX - 2}px, ${event.clientY - 2}px, 0)`;
    }, { passive: true });

    document.documentElement.addEventListener('mouseleave', () => {
      cursor.style.opacity = '0';
    });

    window.addEventListener('blur', () => {
      cursor.style.opacity = '0';
    });
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initialize, { once: true });
  } else {
    initialize();
  }
})();
