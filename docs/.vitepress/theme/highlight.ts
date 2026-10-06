import type { HighlighterCore } from 'shiki/core';

let highlighter: Promise<HighlighterCore> | undefined;

/** Browser-side Shiki with the same themes VitePress uses for Markdown code blocks. */
export function loadHighlighter(): Promise<HighlighterCore> {
  highlighter ??= Promise.all([
    import('shiki/core'),
    import('shiki/engine/javascript'),
  ]).then(([{ createHighlighterCore }, { createJavaScriptRegexEngine }]) =>
    createHighlighterCore({
      themes: [
        import('shiki/themes/github-light.mjs'),
        import('shiki/themes/github-dark.mjs'),
      ],
      langs: [import('shiki/langs/tsx.mjs')],
      engine: createJavaScriptRegexEngine(),
    })
  );
  return highlighter;
}
