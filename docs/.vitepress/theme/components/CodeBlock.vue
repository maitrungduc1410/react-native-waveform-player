<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { loadHighlighter } from '../highlight';

const props = withDefaults(defineProps<{ code: string; lang?: string }>(), {
  lang: 'tsx',
});

const highlighted = ref('');

function escapeHtml(text: string): string {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Same markup as a VitePress Markdown code block, so its styles and copy button apply.
const html = computed(
  () =>
    `<button title="Copy Code" class="copy"></button><span class="lang">${props.lang}</span>` +
    (highlighted.value ||
      `<pre class="shiki vp-code"><code>${escapeHtml(props.code)}</code></pre>`)
);

async function highlight() {
  const code = props.code;
  const highlighter = await loadHighlighter();
  if (code !== props.code) return;
  highlighted.value = highlighter.codeToHtml(code, {
    lang: props.lang,
    themes: { light: 'github-light', dark: 'github-dark' },
    defaultColor: false,
    transformers: [
      {
        pre(node) {
          this.addClassToHast(node, 'vp-code');
        },
      },
    ],
  });
}

onMounted(() => {
  highlight();
  watch(() => props.code, highlight);
});
</script>

<template>
  <div :class="`language-${lang} vp-adaptive-theme code-block`" v-html="html" />
</template>

<style scoped>
.vp-doc .code-block {
  margin: 16px 0 0;
  border-radius: 8px;
}
</style>
