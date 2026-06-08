const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

function updateMeters() {
  if (reduceMotion) return;

  document.querySelectorAll("[data-meter] i").forEach((bar, index) => {
    const base = 0.38 + index * 0.06;
    const movement = Math.sin(Date.now() / 280 + index * 0.9) * 0.28;
    const level = Math.max(0.22, Math.min(1, base + movement + Math.random() * 0.10));
    bar.style.transform = `scaleY(${level})`;
    bar.style.opacity = `${0.36 + level * 0.55}`;
  });
}

function wirePatchConsole() {
  const sources = document.querySelectorAll(".patch-source");
  const outputs = document.querySelectorAll(".patch-output");
  const routes = {
    spotify: 0,
    music: 1,
    chrome: 2
  };

  sources.forEach((button) => {
    button.addEventListener("click", () => {
      sources.forEach((source) => source.classList.remove("active"));
      outputs.forEach((output) => output.classList.remove("active"));
      button.classList.add("active");
      const output = outputs[routes[button.dataset.route] ?? 0];
      output?.classList.add("active");
    });
  });
}

wirePatchConsole();
updateMeters();
setInterval(updateMeters, 140);
