const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
let activeRouteIndex = 0;

function updateMeters() {
  if (reduceMotion) return;

  document.querySelectorAll("[data-meter] i").forEach((bar, index) => {
    const base = 0.34 + index * 0.065;
    const movement = Math.sin(performance.now() / 260 + index * 0.82) * 0.28;
    const pulse = Math.sin(performance.now() / 720) * 0.08;
    const level = Math.max(0.22, Math.min(1, base + movement + pulse));
    bar.style.transform = `scaleY(${level})`;
    bar.style.opacity = `${0.36 + level * 0.55}`;
  });

  requestAnimationFrame(updateMeters);
}

function wirePatchConsole() {
  const sources = document.querySelectorAll(".patch-source");
  const outputs = document.querySelectorAll(".patch-output");
  const routes = {
    spotify: 0,
    music: 1,
    chrome: 2
  };

  function activateRoute(button) {
    sources.forEach((source) => source.classList.remove("active"));
    outputs.forEach((output) => output.classList.remove("active"));
    button.classList.add("active");
    const output = outputs[routes[button.dataset.route] ?? 0];
    output?.classList.add("active");
    activeRouteIndex = Array.from(sources).indexOf(button);
  }

  sources.forEach((button, index) => {
    button.addEventListener("click", () => {
      activeRouteIndex = index;
      activateRoute(button);
    });
  });

  if (!reduceMotion && sources.length > 1) {
    setInterval(() => {
      const hovered = document.querySelector(".patch-console:hover");
      if (hovered) return;
      activeRouteIndex = (activeRouteIndex + 1) % sources.length;
      activateRoute(sources[activeRouteIndex]);
    }, 3600);
  }
}

wirePatchConsole();
updateMeters();
