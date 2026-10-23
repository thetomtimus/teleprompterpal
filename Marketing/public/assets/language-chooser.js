(() => {
  const pickers = document.querySelectorAll('details[data-language-picker]');
  pickers.forEach(picker => picker.addEventListener('toggle', () => {
    if (picker.open) document.querySelector('.mobile-menu')?.removeAttribute('open');
  }));
  document.querySelector('.mobile-menu')?.addEventListener('toggle', event => {
    if (event.currentTarget.open) pickers.forEach(picker => { picker.open = false; });
  });
  document.addEventListener('click', event => pickers.forEach(picker => {
    if (!picker.contains(event.target)) picker.open = false;
  }));
  document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return;
    pickers.forEach(picker => {
      if (picker.open) { picker.open = false; picker.querySelector('summary')?.focus(); }
    });
  });
})();
