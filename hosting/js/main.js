(() => {
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Store CTAs: live http(s) links open in a new tab; empty URL = App Store მალე only
  document.querySelectorAll("[data-store]").forEach((el) => {
    const url = (el.getAttribute("data-store-url") || el.getAttribute("href") || "").trim();
    const isLive = /^https?:\/\//i.test(url) && url !== "#";
    if (isLive) {
      el.setAttribute("href", url);
      el.setAttribute("target", "_blank");
      el.setAttribute("rel", "noopener noreferrer");
      el.removeAttribute("aria-disabled");
      el.classList.remove("store-btn--soon");
    } else {
      el.addEventListener("click", (event) => {
        event.preventDefault();
      });
    }
  });

  if (reduce || !("IntersectionObserver" in window)) {
    document.querySelectorAll(".reveal").forEach((node) => node.classList.add("is-in"));
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-in");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.18, rootMargin: "0px 0px -8% 0px" }
  );

  document.querySelectorAll(".reveal").forEach((node) => observer.observe(node));
})();
