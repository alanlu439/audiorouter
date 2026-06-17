const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const systemDarkQuery = window.matchMedia("(prefers-color-scheme: dark)");
const themeModeStorageKey = "audiorouter-theme-mode";
const themeModes = ["auto", "dark", "light"];
let activeRouteIndex = 0;

function wirePageTransitions() {
  if (reduceMotion) return;

  const root = document.documentElement;
  root.classList.add("page-transition-ready");

  window.addEventListener("pageshow", () => {
    root.classList.remove("is-navigating");
    root.classList.add("page-transition-ready");
  });

  document.addEventListener("click", (event) => {
    if (
      event.defaultPrevented ||
      event.button !== 0 ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey
    ) {
      return;
    }

    const target = event.target instanceof Element ? event.target : event.target?.parentElement;
    const link = target?.closest("a[href]");
    if (!(link instanceof HTMLAnchorElement) || !shouldAnimateLink(link)) return;

    event.preventDefault();
    root.classList.add("is-navigating");
    window.setTimeout(() => {
      window.location.href = link.href;
    }, 150);
  });
}

function shouldAnimateLink(link) {
  const url = new URL(link.href, window.location.href);
  const samePage = url.pathname === window.location.pathname && url.search === window.location.search;
  const isHtmlPage = url.pathname.endsWith("/") || url.pathname.endsWith(".html") || !url.pathname.includes(".");

  return (
    url.origin === window.location.origin &&
    isHtmlPage &&
    !samePage &&
    !link.target &&
    !link.hasAttribute("download")
  );
}

function normalizeThemeMode(mode) {
  return themeModes.includes(mode) ? mode : "auto";
}

function effectiveThemeForMode(mode) {
  const normalizedMode = normalizeThemeMode(mode);
  if (normalizedMode === "auto") {
    return systemDarkQuery.matches ? "dark" : "light";
  }
  return normalizedMode;
}

function currentStoredThemeMode() {
  try {
    return localStorage.getItem(themeModeStorageKey);
  } catch {
    return null;
  }
}

function setStoredThemeMode(mode) {
  try {
    localStorage.setItem(themeModeStorageKey, normalizeThemeMode(mode));
  } catch {
    // The theme still changes for this page even if storage is blocked.
  }
}

function updateThemeToggle(mode, effectiveTheme) {
  const toggle = document.querySelector(".theme-toggle");
  if (!toggle) return;

  const normalizedMode = normalizeThemeMode(mode);
  const nextMode = normalizedMode === "auto" ? "dark" : normalizedMode === "dark" ? "light" : "auto";
  const label = normalizedMode === "auto" ? "Auto" : normalizedMode === "dark" ? "Dark" : "Light";
  const isDark = effectiveTheme === "dark";
  toggle.setAttribute("aria-pressed", String(isDark));
  toggle.setAttribute("aria-label", `Theme mode ${label}. Switch to ${nextMode} mode`);
  toggle.querySelector(".theme-toggle-label").textContent = label;
}

function applyThemeMode(mode) {
  const normalizedMode = normalizeThemeMode(mode);
  const effectiveTheme = effectiveThemeForMode(normalizedMode);
  document.documentElement.dataset.themeMode = normalizedMode;
  document.documentElement.dataset.theme = effectiveTheme;
  const pageThemeColor = document.body.classList.contains("windows-site")
    ? "#07111f"
    : (effectiveTheme === "dark" ? "#07111f" : "#e8fffb");
  document.querySelector('meta[name="theme-color"]')?.setAttribute("content", pageThemeColor);
  updateThemeToggle(normalizedMode, effectiveTheme);
}

function wireThemeToggle() {
  const toggle = document.querySelector(".theme-toggle");
  if (!toggle) return;

  applyThemeMode(document.documentElement.dataset.themeMode || currentStoredThemeMode() || "auto");

  toggle.addEventListener("click", () => {
    const currentMode = normalizeThemeMode(document.documentElement.dataset.themeMode);
    const nextMode = currentMode === "auto" ? "dark" : currentMode === "dark" ? "light" : "auto";
    setStoredThemeMode(nextMode);
    applyThemeMode(nextMode);
  });

  const syncSystemTheme = () => {
    if (normalizeThemeMode(document.documentElement.dataset.themeMode) !== "auto") return;
    applyThemeMode("auto");
  };

  if (systemDarkQuery.addEventListener) {
    systemDarkQuery.addEventListener("change", syncSystemTheme);
  } else if (systemDarkQuery.addListener) {
    systemDarkQuery.addListener(syncSystemTheme);
  }
}

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

  document.querySelectorAll("[data-meter] span").forEach((bar, index) => {
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
    const route = button.dataset.route;
    sources.forEach((source) => source.classList.remove("active"));
    outputs.forEach((output) => output.classList.remove("active"));
    button.classList.add("active");
    const routeOutputIndex = routes[route];
    if (routeOutputIndex !== undefined) {
      outputs[routeOutputIndex]?.classList.add("active");
    }
    activeRouteIndex = Array.from(sources).indexOf(button);
  }

  sources.forEach((button, index) => {
    button.addEventListener("click", () => {
      activeRouteIndex = index;
      activateRoute(button);
    });
  });

  if (!reduceMotion && sources.length > 1) {
    const routedSources = Array.from(sources).filter((source) => source.dataset.route in routes);
    setInterval(() => {
      const hovered = document.querySelector(".patch-console:hover");
      if (hovered) return;
      activeRouteIndex = (activeRouteIndex + 1) % routedSources.length;
      activateRoute(routedSources[activeRouteIndex]);
    }, 3600);
  }
}

wirePageTransitions();
wireThemeToggle();
wireMobileNavigation();
wirePatchConsole();
updateMeters();
