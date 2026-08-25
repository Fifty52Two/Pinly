const nav = document.querySelector(".site-nav");
const year = document.querySelector("[data-year]");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

if (year) year.textContent = new Date().getFullYear();

const updateNav = () => nav?.classList.toggle("scrolled", window.scrollY > 12);
updateNav();
window.addEventListener("scroll", updateNav, { passive: true });

document.querySelectorAll("details").forEach((detail) => {
  detail.addEventListener("toggle", () => {
    if (!detail.open) return;
    document.querySelectorAll("details[open]").forEach((other) => {
      if (other !== detail) other.open = false;
    });
  });
});

const revealTargets = document.querySelectorAll("[data-reveal]");
if (reducedMotion.matches || !("IntersectionObserver" in window)) {
  revealTargets.forEach((target) => target.classList.add("is-visible"));
} else {
  const revealObserver = new IntersectionObserver((entries, observer) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("is-visible");
      observer.unobserve(entry.target);
    });
  }, { threshold: 0.16 });
  revealTargets.forEach((target) => revealObserver.observe(target));
}

const story = document.querySelector("[data-story]");
const storySteps = [...document.querySelectorAll("[data-story-step]")];
const storyProgress = document.querySelector("[data-story-progress]");

const activateStoryStep = (step) => {
  const index = storySteps.indexOf(step);
  storySteps.forEach((candidate) => candidate.classList.toggle("is-active", candidate === step));
  if (storyProgress && index >= 0) {
    storyProgress.style.setProperty("--story-progress", `${((index + 1) / storySteps.length) * 100}%`);
  }
};

if (story && storySteps.length) {
  activateStoryStep(storySteps[0]);
  if (!reducedMotion.matches && "IntersectionObserver" in window) {
    const storyObserver = new IntersectionObserver((entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (visible) activateStoryStep(visible.target);
    }, { rootMargin: "-30% 0px -30% 0px", threshold: [0.2, 0.45, 0.7] });
    storySteps.forEach((step) => storyObserver.observe(step));
  } else {
    storySteps.forEach((step) => step.classList.add("is-active"));
  }
}
