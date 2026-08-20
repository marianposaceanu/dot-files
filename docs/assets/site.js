(() => {
  const toc = document.querySelector(".toc");

  if (!toc) {
    return;
  }

  const links = Array.from(toc.querySelectorAll('a[href^="#"]'));
  const sections = links
    .map((link) => {
      const id = decodeURIComponent(link.getAttribute("href").slice(1));
      const section = document.getElementById(id);
      return section ? { link, section } : null;
    })
    .filter(Boolean);

  if (sections.length === 0) {
    return;
  }

  toc.classList.add("is-enhanced");

  const setActive = (activeLink) => {
    links.forEach((link) => {
      link.classList.toggle("is-active", link === activeLink);
      if (link === activeLink) {
        link.setAttribute("aria-current", "true");
      } else {
        link.removeAttribute("aria-current");
      }
    });
  };

  const updateActiveFromScroll = () => {
    const atPageEnd =
      window.scrollY + window.innerHeight >=
      document.documentElement.scrollHeight - 2;
    let current = atPageEnd ? sections[sections.length - 1] : null;

    if (!current) {
      sections.forEach((candidate) => {
        if (candidate.section.getBoundingClientRect().top <= 140) {
          current = candidate;
        }
      });
    }

    setActive((current || sections[0]).link);
  };

  let updatePending = false;
  const scheduleActiveUpdate = () => {
    if (updatePending) {
      return;
    }

    updatePending = true;
    window.requestAnimationFrame(() => {
      updateActiveFromScroll();
      updatePending = false;
    });
  };

  scheduleActiveUpdate();
  window.addEventListener("scroll", scheduleActiveUpdate, { passive: true });
  window.addEventListener("resize", scheduleActiveUpdate);
  window.addEventListener("hashchange", scheduleActiveUpdate);
})();

(() => {
  const compasses = Array.from(document.querySelectorAll(".moral-compass"));

  if (compasses.length === 0) {
    return;
  }

  const animate = (compass) => compass.classList.add("is-animated");

  if (!("IntersectionObserver" in window)) {
    compasses.forEach(animate);
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries
        .filter((entry) => entry.isIntersecting)
        .forEach((entry) => {
          animate(entry.target);
          observer.unobserve(entry.target);
        });
    },
    { threshold: 0.35 },
  );

  compasses.forEach((compass) => observer.observe(compass));
})();

(() => {
  const navs = Array.from(document.querySelectorAll(".main-navigation"));
  const resultLimit = 12;
  let overlay;
  let dialog;
  let input;
  let status;
  let results;
  let closeButton;
  let searchItemsPromise;
  let lastFocused;
  const boundSearchTriggers = new WeakSet();

  const cleanText = (value) => value.replace(/\s+/g, " ").trim();

  const normalize = (value) =>
    cleanText(value)
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "");

  const indexUrl = () => {
    if (window.location.protocol === "file:") {
      return "index.html";
    }

    return "/";
  };

  const buildItemsFromDocument = (doc) =>
    Array.from(doc.querySelectorAll(".topic-list li"))
      .map((item, index) => {
        const link = item.querySelector(".topic-heading a");
        const description = item.querySelector("span");
        const date = item.querySelector("time.thread-date");

        if (!link) {
          return null;
        }

        const descriptionCopy = description ? description.cloneNode(true) : null;
        descriptionCopy
          ?.querySelectorAll("time")
          .forEach((time) => time.remove());

        const title = cleanText(link.textContent || "");
        const summary = cleanText(descriptionCopy?.textContent || "");
        const dateText = cleanText(date?.textContent || "");
        const searchable = normalize(`${title} ${summary} ${dateText}`);

        return {
          date: dateText,
          description: summary,
          href: link.getAttribute("href"),
          index,
          searchable,
          title,
          titleSearchable: normalize(title),
        };
      })
      .filter(Boolean);

  const currentPageFallback = () => {
    const title = cleanText(
      document.querySelector("h1")?.textContent ||
        document.title.replace(/ [|–-] dot-files$/, ""),
    );
    const description = cleanText(
      document.querySelector(".subtitle")?.textContent ||
        document.querySelector('meta[name="description"]')?.getAttribute("content") ||
        "",
    );
    const date = cleanText(document.querySelector(".article-date")?.textContent || "");

    return [
      {
        date,
        description,
        href: window.location.href,
        index: 0,
        searchable: normalize(`${title} ${description} ${date}`),
        title,
        titleSearchable: normalize(title),
      },
    ];
  };

  const loadSearchItems = () => {
    if (searchItemsPromise) {
      return searchItemsPromise;
    }

    const localItems = buildItemsFromDocument(document);
    if (localItems.length > 0) {
      searchItemsPromise = Promise.resolve(localItems);
      return searchItemsPromise;
    }

    searchItemsPromise = fetch(indexUrl(), {
      headers: { Accept: "text/html" },
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`Search index request failed: ${response.status}`);
        }

        return response.text();
      })
      .then((html) => {
        const doc = new DOMParser().parseFromString(html, "text/html");
        const items = buildItemsFromDocument(doc);
        return items.length > 0 ? items : currentPageFallback();
      })
      .catch(() => currentPageFallback());

    return searchItemsPromise;
  };

  const rankItems = (items, query) => {
    const normalizedQuery = normalize(query);
    const tokens = normalizedQuery.split(" ").filter(Boolean);

    if (tokens.length === 0) {
      return items.slice(0, resultLimit).map((item) => ({ item, score: 0 }));
    }

    return items
      .map((item) => {
        let score = 0;

        for (const token of tokens) {
          if (!item.searchable.includes(token)) {
            return null;
          }

          if (item.titleSearchable.startsWith(token)) {
            score += 16;
          } else if (item.titleSearchable.includes(token)) {
            score += 10;
          } else {
            score += 3;
          }
        }

        return { item, score };
      })
      .filter(Boolean)
      .sort((a, b) => b.score - a.score || a.item.index - b.item.index)
      .slice(0, resultLimit);
  };

  const renderResults = (items, query) => {
    const ranked = rankItems(items, query);
    results.replaceChildren();

    if (ranked.length === 0) {
      status.textContent = "No matching pages.";
      return;
    }

    status.textContent =
      normalize(query).length === 0
        ? "Recent pages"
        : `${ranked.length} matching ${ranked.length === 1 ? "page" : "pages"}`;

    const fragment = document.createDocumentFragment();

    ranked.forEach(({ item }) => {
      const li = document.createElement("li");
      const link = document.createElement("a");
      const title = document.createElement("span");
      const description = document.createElement("span");

      title.className = "search-result-title";
      title.textContent = item.title;
      description.className = "search-result-description";
      description.textContent = item.description;
      link.href = item.href;
      link.append(title, description);

      if (item.date) {
        const date = document.createElement("span");
        date.className = "search-result-date";
        date.textContent = item.date;
        link.append(date);
      }

      li.append(link);
      fragment.append(li);
    });

    results.append(fragment);
  };

  const renderLoading = () => {
    status.textContent = "Loading pages...";
    results.replaceChildren();
  };

  const ensureOverlay = () => {
    if (overlay) {
      return;
    }

    overlay = document.createElement("div");
    overlay.className = "search-overlay";
    overlay.hidden = true;

    dialog = document.createElement("div");
    dialog.className = "search-dialog";
    dialog.setAttribute("role", "dialog");
    dialog.setAttribute("aria-modal", "true");
    dialog.setAttribute("aria-labelledby", "site-search-title");

    const header = document.createElement("div");
    header.className = "search-header";

    const title = document.createElement("h2");
    title.id = "site-search-title";
    title.textContent = "Search dot-files";

    closeButton = document.createElement("button");
    closeButton.className = "search-close";
    closeButton.type = "button";
    closeButton.setAttribute("aria-label", "Close search");
    closeButton.textContent = "x";

    const label = document.createElement("label");
    label.className = "visually-hidden";
    label.setAttribute("for", "site-search-input");
    label.textContent = "Search articles";

    input = document.createElement("input");
    input.id = "site-search-input";
    input.className = "search-input";
    input.type = "search";
    input.autocomplete = "off";
    input.spellcheck = false;
    input.placeholder = "Search articles";

    status = document.createElement("p");
    status.className = "search-status";
    status.setAttribute("aria-live", "polite");

    results = document.createElement("ol");
    results.className = "search-results";

    header.append(title, closeButton);
    dialog.append(header, label, input, status, results);
    overlay.append(dialog);
    document.body.append(overlay);

    overlay.addEventListener("click", (event) => {
      if (event.target === overlay) {
        closeSearch();
      }
    });

    closeButton.addEventListener("click", closeSearch);

    input.addEventListener("input", () => {
      loadSearchItems().then((items) => renderResults(items, input.value));
    });

    input.addEventListener("keydown", (event) => {
      if (event.key !== "Enter") {
        return;
      }

      const firstResult = results.querySelector("a");
      if (firstResult) {
        firstResult.click();
      }
    });
  };

  const openSearch = () => {
    ensureOverlay();
    lastFocused = document.activeElement;
    overlay.hidden = false;
    document.body.classList.add("search-is-open");
    input.value = "";
    renderLoading();
    input.focus();
    loadSearchItems().then((items) => renderResults(items, input.value));
  };

  function closeSearch() {
    if (!overlay || overlay.hidden) {
      return;
    }

    overlay.hidden = true;
    document.body.classList.remove("search-is-open");

    if (lastFocused && typeof lastFocused.focus === "function") {
      lastFocused.focus();
    }
  }

  const bindSearchTrigger = (trigger) => {
    if (boundSearchTriggers.has(trigger)) {
      return;
    }

    boundSearchTriggers.add(trigger);
    trigger.addEventListener("click", openSearch);
  };

  const addSearchNavigation = () => {
    navs.forEach((nav) => {
      if (nav.querySelector("[data-search-open]")) {
        return;
      }

      const divider = document.createElement("span");
      divider.className = "nav-divider";
      divider.setAttribute("aria-hidden", "true");
      divider.textContent = "|";

      const button = document.createElement("button");
      button.className = "nav-search";
      button.type = "button";
      button.dataset.searchOpen = "true";
      button.setAttribute("aria-haspopup", "dialog");
      button.textContent = "search";
      bindSearchTrigger(button);

      nav.append(divider, button);
    });
  };

  document.addEventListener("keydown", (event) => {
    if (event.defaultPrevented) {
      return;
    }

    if (event.key === "Escape" && overlay && !overlay.hidden) {
      event.preventDefault();
      closeSearch();
    }
  });

  addSearchNavigation();
  document.querySelectorAll("[data-search-open]").forEach(bindSearchTrigger);
})();

(() => {
  const tabGroups = Array.from(document.querySelectorAll("[data-language-tabs]"));

  if (tabGroups.length === 0) {
    return;
  }

  const hashTarget = () => {
    if (!window.location.hash) {
      return null;
    }

    try {
      return document.getElementById(
        decodeURIComponent(window.location.hash.slice(1)),
      );
    } catch {
      return null;
    }
  };

  tabGroups.forEach((group) => {
    const tabs = Array.from(group.querySelectorAll("[data-language-tab]"));
    const panels = Array.from(group.querySelectorAll("[data-language-panel]"));

    if (tabs.length === 0 || panels.length === 0) {
      return;
    }

    const tabForLanguage = (language) =>
      tabs.find((tab) => tab.dataset.languageTab === language);

    const tabForTarget = (target) => {
      if (!target) {
        return null;
      }

      const panel = panels.find(
        (candidate) => candidate === target || candidate.contains(target),
      );

      return panel ? tabForLanguage(panel.dataset.languagePanel) : null;
    };

    const activate = (activeTab, { focus = false } = {}) => {
      const activeLanguage = activeTab.dataset.languageTab;

      tabs.forEach((tab) => {
        const isActive = tab === activeTab;
        tab.setAttribute("aria-selected", String(isActive));
        tab.tabIndex = isActive ? 0 : -1;
      });

      panels.forEach((panel) => {
        panel.hidden = panel.dataset.languagePanel !== activeLanguage;
      });

      if (focus) {
        activeTab.focus();
      }
    };

    group.classList.add("is-enhanced");
    activate(
      tabForTarget(hashTarget()) ||
        tabs.find((tab) => tab.getAttribute("aria-selected") === "true") ||
        tabs[0],
    );

    tabs.forEach((tab, index) => {
      tab.addEventListener("click", () => activate(tab));

      tab.addEventListener("keydown", (event) => {
        let nextIndex;

        if (event.key === "ArrowRight") {
          nextIndex = (index + 1) % tabs.length;
        } else if (event.key === "ArrowLeft") {
          nextIndex = (index - 1 + tabs.length) % tabs.length;
        } else if (event.key === "Home") {
          nextIndex = 0;
        } else if (event.key === "End") {
          nextIndex = tabs.length - 1;
        } else {
          return;
        }

        event.preventDefault();
        activate(tabs[nextIndex], { focus: true });
      });
    });

    document.querySelectorAll("[data-language-link]").forEach((link) => {
      link.addEventListener("click", (event) => {
        const tab = tabForLanguage(link.dataset.languageLink);
        const panel = panels.find(
          (candidate) =>
            candidate.dataset.languagePanel === link.dataset.languageLink,
        );

        if (!tab || !panel) {
          return;
        }

        event.preventDefault();
        activate(tab);
        window.history.pushState(null, "", `#${panel.id}`);
        panel.scrollIntoView({ block: "start" });
      });
    });

    window.addEventListener("hashchange", () => {
      const tab = tabForTarget(hashTarget());

      if (tab) {
        activate(tab);
      }
    });
  });
})();

(() => {
  const article = document.querySelector(".site-article .article-flow");

  if (!article) {
    return;
  }

  const progress = document.createElement("div");
  progress.className = "reading-progress";
  progress.setAttribute("aria-hidden", "true");
  document.body.prepend(progress);

  const updateProgress = () => {
    const articleTop = window.scrollY + article.getBoundingClientRect().top;
    const available = Math.max(article.offsetHeight - window.innerHeight, 1);
    const ratio = Math.min(
      1,
      Math.max(0, (window.scrollY - articleTop + 24) / available),
    );
    progress.style.width = `${ratio * 100}%`;
  };

  updateProgress();
  document.addEventListener("scroll", updateProgress, { passive: true });
  window.addEventListener("resize", updateProgress);
})();

(() => {
  const toc = document.querySelector(".site-article .toc");
  const article = document.querySelector(".site-article .article-flow");
  const list = toc?.querySelector("ol");

  if (!toc || !article || !list) {
    return;
  }

  const details = document.createElement("details");
  details.className = "mobile-contents";

  const summary = document.createElement("summary");
  summary.textContent = "Contents";

  details.append(summary, list.cloneNode(true));
  article.before(details);
  document.body.classList.add("has-mobile-contents");
})();

(() => {
  const archive = document.querySelector(".site-home .archive-index");
  const input = archive?.querySelector("[data-archive-filter]");
  const status = archive?.querySelector("[data-archive-filter-status]");
  const more = archive?.querySelector("[data-archive-more]");
  const items = Array.from(archive?.querySelectorAll(".archive-list > li") || []);
  const initialLimit = 12;
  let expanded = false;

  if (!archive || !input || !status || !more || items.length === 0) {
    return;
  }

  const normalize = (value) =>
    value
      .replace(/\s+/g, " ")
      .trim()
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "");

  const update = () => {
    const query = normalize(input.value);
    let matches = 0;
    let visible = 0;

    items.forEach((item, index) => {
      const matchesQuery = !query || normalize(item.textContent).includes(query);
      const withinLimit = expanded || query || index < initialLimit;
      item.hidden = !matchesQuery || !withinLimit;
      if (matchesQuery) matches += 1;
      if (!item.hidden) visible += 1;
    });

    more.hidden = Boolean(query) || items.length <= initialLimit;
    more.setAttribute("aria-expanded", String(expanded));
    more.textContent = expanded
      ? "Show fewer investigations"
      : "Show more investigations";
    status.textContent = query
      ? `${matches} matching ${matches === 1 ? "investigation" : "investigations"}.`
      : `Showing ${visible} of ${items.length} investigations.`;
  };

  archive.classList.add("is-filterable");
  input.addEventListener("input", update);
  more.addEventListener("click", () => {
    expanded = !expanded;
    update();
  });
  update();
})();
