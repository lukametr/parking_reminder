(() => {
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Store CTAs: paste URL into data-store-url (see docs/landing-page.md)
  document.querySelectorAll("[data-store]").forEach((el) => {
    const url = (el.getAttribute("data-store-url") || "").trim();
    if (url && /^https?:\/\//i.test(url)) {
      el.setAttribute("href", url);
      el.removeAttribute("aria-disabled");
      el.addEventListener("click", () => {});
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
