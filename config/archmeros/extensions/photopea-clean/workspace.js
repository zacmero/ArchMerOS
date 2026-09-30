(() => {
  let pending = false;
  let correcting = false;

  function schedule() {
    if (pending || correcting) return;
    pending = true;
    queueMicrotask(() => {
      pending = false;
      const row = document.querySelector('body > .app > div:first-child > .flexrow');
      if (!row || !row.children.length) return;
      const occupied = Array.from(row.children).reduce(
        (width, child) => width + child.getBoundingClientRect().width, 0
      );
      const gap = Math.round(row.clientWidth - occupied);
      if (gap < 2 || gap > 400) return;

      // Photopea subtracts its ad allowance before sizing the canvas and panels.
      // Compensate only during its resize handler, then restore the real viewport.
      const descriptor = Object.getOwnPropertyDescriptor(window, 'innerWidth');
      if (!descriptor || !descriptor.configurable) return;
      const width = window.innerWidth;
      correcting = true;
      try {
        Object.defineProperty(window, 'innerWidth', {
          configurable: true, get: () => width + gap
        });
        window.dispatchEvent(new Event('resize'));
      } finally {
        Object.defineProperty(window, 'innerWidth', descriptor);
        correcting = false;
      }
    });
  }

  window.addEventListener('resize', schedule);
  new MutationObserver(schedule).observe(document.body, {
    childList: true, subtree: true
  });
  schedule();
})();
