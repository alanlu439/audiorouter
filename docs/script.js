const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
let activeRouteIndex = 0;

const routeLabels = {
  spotify: "Spotify",
  music: "Apple Music",
  chrome: "Chrome"
};

const routeOutputs = {
  Spotify: "AirPods Pro",
  "Apple Music": "MacBook Speakers",
  Chrome: "Group Play 1",
  "Custom App": "Follow System Output"
};

function wireMobileNavigation() {
  const header = document.querySelector(".site-header");
  const toggle = document.querySelector(".nav-toggle");
  const links = document.querySelectorAll(".nav-links a");
  if (!header || !toggle) return;

  function setOpen(isOpen) {
    header.classList.toggle("nav-open", isOpen);
    toggle.setAttribute("aria-expanded", String(isOpen));
  }

  toggle.addEventListener("click", () => {
    setOpen(!header.classList.contains("nav-open"));
  });

  links.forEach((link) => {
    link.addEventListener("click", () => setOpen(false));
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") setOpen(false);
  });
}

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
  const sourceSelect = document.querySelector("#route-source-select");
  const outputSelect = document.querySelector("#route-output-select");
  const gainInput = document.querySelector("#route-gain");
  const resultText = document.querySelector("#route-result-text");
  const routes = {
    spotify: 0,
    music: 1,
    chrome: 2
  };

  function activateRoute(button) {
    const route = button.dataset.route;
    sources.forEach((source) => source.classList.remove("active"));
    outputs.forEach((output) => output.classList.remove("active"));
    button.classList.add("active");
    const routeOutputIndex = routes[route];
    if (routeOutputIndex !== undefined) {
      outputs[routeOutputIndex]?.classList.add("active");
    }
    activeRouteIndex = Array.from(sources).indexOf(button);

    if (route && routeLabels[route] && sourceSelect && outputSelect) {
      const sourceName = routeLabels[route];
      sourceSelect.value = sourceName;
      outputSelect.value = routeOutputs[sourceName] ?? outputSelect.value;
      updateRouteLab();
    }
  }

  function updateRouteLab() {
    if (!sourceSelect || !outputSelect || !gainInput || !resultText) return;

    const sourceName = sourceSelect.value;
    const outputName = outputSelect.value;
    const gainValue = gainInput.value;
    resultText.textContent = `${sourceName} to ${outputName} at ${gainValue}%`;

    sources.forEach((source) => {
      const sourceLabel = routeLabels[source.dataset.route];
      source.classList.toggle("active", sourceLabel === sourceName);
    });

    outputs.forEach((output) => {
      const label = output.textContent.trim();
      output.classList.toggle("active", label.includes(outputName));
    });
  }

  sources.forEach((button, index) => {
    button.addEventListener("click", () => {
      activeRouteIndex = index;
      activateRoute(button);
    });
  });

  sourceSelect?.addEventListener("change", () => {
    outputSelect.value = routeOutputs[sourceSelect.value] ?? outputSelect.value;
    updateRouteLab();
  });
  outputSelect?.addEventListener("change", updateRouteLab);
  gainInput?.addEventListener("input", updateRouteLab);
  updateRouteLab();

  if (!reduceMotion && sources.length > 1) {
    const routedSources = Array.from(sources).filter((source) => source.dataset.route in routes);
    setInterval(() => {
      const hovered = document.querySelector(".patch-console:hover");
      if (hovered || document.activeElement?.closest(".route-lab")) return;
      activeRouteIndex = (activeRouteIndex + 1) % routedSources.length;
      activateRoute(routedSources[activeRouteIndex]);
    }, 3600);
  }
}

wireMobileNavigation();
wirePatchConsole();
updateMeters();
