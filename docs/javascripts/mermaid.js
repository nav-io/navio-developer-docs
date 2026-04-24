// Initialise Mermaid after page navigation. Material's instant-navigation
// mode reuses the DOM, so we need to re-run Mermaid on each page change.
document$.subscribe(() => {
    if (typeof mermaid === "undefined") return;

    const isDark = document.body.getAttribute("data-md-color-scheme") === "slate";
    mermaid.initialize({
        startOnLoad: false,
        theme: isDark ? "dark" : "default",
        themeVariables: {
            primaryColor: "#10152e",
            primaryTextColor: "#e6edff",
            primaryBorderColor: "#00d4ff",
            lineColor: "#00d4ff",
            secondaryColor: "#7b5cff",
            tertiaryColor: "#ff5cf0",
            background: "#0a0e27",
            mainBkg: "#10152e",
            fontFamily: "JetBrains Mono, ui-monospace, monospace",
        },
        securityLevel: "loose",
    });

    const nodes = document.querySelectorAll(".mermaid:not([data-processed='true'])");
    if (nodes.length > 0) {
        mermaid.run({ nodes });
    }
});
