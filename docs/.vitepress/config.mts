import { readFileSync } from 'node:fs';
import {
  type DefaultTheme,
  type HeadConfig,
  type PageData,
  defineConfig,
} from 'vitepress';

const repo = 'https://github.com/maitrungduc1410/react-native-waveform-player';
const recorder = 'https://maitrungduc1410.github.io/react-native-waveform-recorder/';
const base = '/react-native-waveform-player/';
// Production origin + base. Sitemap URLs and canonical links are built from it.
const site = `https://maitrungduc1410.github.io${base}`;
const { version } = JSON.parse(
  readFileSync(new URL('../../package.json', import.meta.url), 'utf8')
) as { version: string };

// Written by `yarn api` (TypeDoc) before VitePress runs.
const apiSidebar = JSON.parse(
  readFileSync(new URL('../api/typedoc-sidebar.json', import.meta.url), 'utf8')
) as DefaultTheme.SidebarItem[];

const slugs = [
  '',
  'installation',
  'quick-start',
  'props',
  'events',
  'ref-methods',
  'styling',
  'playback',
  'background-playback',
  'platform-notes',
  'troubleshooting',
] as const;

type Labels = {
  guide: string;
  api: string;
  recorder: string;
  groups: [string, string, string, string];
  pages: Record<(typeof slugs)[number], string>;
};

const groups: (typeof slugs)[number][][] = [
  ['', 'installation', 'quick-start'],
  ['props', 'events', 'ref-methods'],
  ['styling', 'playback', 'background-playback'],
  ['platform-notes', 'troubleshooting'],
];

function guideSidebar(prefix: string, l: Labels): DefaultTheme.SidebarItem[] {
  return groups.map((group, i) => ({
    text: l.groups[i],
    items: group.map((slug) => ({
      text: l.pages[slug],
      link: `${prefix}/guide/${slug}`,
    })),
  }));
}

function themeConfig(prefix: string, l: Labels): DefaultTheme.Config {
  return {
    nav: [
      {
        text: l.guide,
        link: `${prefix}/guide/`,
        activeMatch: `^${prefix}/guide/`,
      },
      { text: l.api, link: '/api/', activeMatch: '^/api/' },
      {
        text: `v${version}`,
        items: [
          {
            text: 'npm',
            link: 'https://www.npmjs.com/package/react-native-waveform-player',
          },
          { text: l.recorder, link: recorder },
        ],
      },
    ],
    sidebar: {
      [`${prefix}/guide/`]: guideSidebar(prefix, l),
      '/api/': [{ text: l.api, link: '/api/', items: apiSidebar }],
    },
  };
}

const en: Labels = {
  guide: 'Guide',
  api: 'API reference',
  recorder: 'Waveform Recorder',
  groups: ['Introduction', 'Component API', 'Guides', 'Platforms and help'],
  pages: {
    '': 'What is it?',
    'installation': 'Installation',
    'quick-start': 'Quick start',
    'props': 'Props',
    'events': 'Events',
    'ref-methods': 'Ref methods',
    'styling': 'Styling',
    'playback': 'Speed and playback',
    'background-playback': 'Background playback',
    'platform-notes': 'Platform notes',
    'troubleshooting': 'Troubleshooting',
  },
};

const vi: Labels = {
  guide: 'Hướng dẫn',
  api: 'Tài liệu API',
  recorder: 'Waveform Recorder',
  groups: ['Giới thiệu', 'API của component', 'Hướng dẫn', 'Nền tảng và hỗ trợ'],
  pages: {
    '': 'Tổng quan',
    'installation': 'Cài đặt',
    'quick-start': 'Bắt đầu nhanh',
    'props': 'Props',
    'events': 'Sự kiện',
    'ref-methods': 'Phương thức ref',
    'styling': 'Tùy biến giao diện',
    'playback': 'Tốc độ và phát lại',
    'background-playback': 'Phát trong nền',
    'platform-notes': 'Lưu ý theo nền tảng',
    'troubleshooting': 'Khắc phục sự cố',
  },
};

const zh: Labels = {
  guide: '指南',
  api: 'API 参考',
  recorder: 'Waveform Recorder',
  groups: ['入门', '组件 API', '指南', '平台与排错'],
  pages: {
    '': '概览',
    'installation': '安装',
    'quick-start': '快速开始',
    'props': 'Props',
    'events': '事件',
    'ref-methods': 'Ref 方法',
    'styling': '样式',
    'playback': '倍速与播放控制',
    'background-playback': '后台播放',
    'platform-notes': '平台说明',
    'troubleshooting': '故障排查',
  },
};

// SEO: locale metadata used for hreflang, og:locale and the preview image alt text.
const seoLocales = {
  root: {
    prefix: '',
    lang: 'en-US',
    og: 'en_US',
    imageAlt:
      'React Native Waveform Player: a fuchsia voice-note bubble with a play button, a waveform and a speed pill',
  },
  vi: {
    prefix: 'vi/',
    lang: 'vi-VN',
    og: 'vi_VN',
    imageAlt:
      'React Native Waveform Player: bong bóng tin nhắn thoại màu hồng tím có nút phát, dạng sóng và nút tốc độ',
  },
  zh: {
    prefix: 'zh/',
    lang: 'zh-CN',
    og: 'zh_CN',
    imageAlt: 'React Native Waveform Player：紫红色语音消息气泡，带播放按钮、波形和倍速按钮',
  },
} as const;
type SeoLocale = keyof typeof seoLocales;

function localeOf(page: string): SeoLocale {
  const first = page.split('/')[0];
  return first === 'vi' || first === 'zh' ? first : 'root';
}

/** `vi/guide/index.md` -> `vi/guide/`, `api/variables/AudioWaveformView.md` -> `api/variables/AudioWaveformView`. */
function pageUrl(page: string): string {
  return page.replace(/(^|\/)index\.md$/, '$1').replace(/\.md$/, '');
}

/** Description for generated TypeDoc pages, which have no frontmatter. */
function apiDescription(relativePath: string): string | undefined {
  const m = relativePath.match(/^api\/(?:(\w[\w-]*)\/)?([^/]+)\.md$/);
  if (!m) return undefined;
  const [, kind, name] = m;
  const lib = 'react-native-waveform-player';
  switch (kind) {
    case undefined:
      return `API reference for ${lib}: the AudioWaveformView component, its props, ref methods and every event payload type, generated from the TypeScript source.`;
    case 'variables':
      return `API reference for the ${name} component in ${lib}: the native voice-note player with waveform, scrubbing and speed control.`;
    case 'type-aliases':
      return `API reference for the ${name} type in ${lib}, with its TypeScript definition and what each member means.`;
    default:
      return undefined;
  }
}

export default defineConfig({
  title: 'React Native Waveform Player',
  description:
    'Native voice-note player for React Native: an animated waveform with scrubbing, a speed pill and background playback, in Swift and Kotlin.',
  base,
  cleanUrls: true,
  lastUpdated: true,
  appearance: 'dark',
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}logo.svg` }],
    [
      'link',
      {
        rel: 'apple-touch-icon',
        sizes: '180x180',
        href: `${base}apple-touch-icon.png`,
      },
    ],
    ['meta', { name: 'theme-color', content: '#D946EF' }],
    [
      'meta',
      {
        name: 'google-site-verification',
        content: 'tQKWpMESb7_XYCOMCID91lFgoQ4_dt3sqGoXzuRu-ZQ',
      },
    ],
  ],
  sitemap: {
    // VitePress 1.6 builds item URLs without `base`, so the hostname carries it.
    hostname: site,
    transformItems: (items) =>
      items.map((item) => {
        const en = item.links?.find((l) => l.lang === seoLocales.root.lang);
        return en
          ? { ...item, links: [...item.links!, { lang: 'x-default', url: en.url }] }
          : item;
      }),
  },
  transformPageData(pageData: PageData) {
    const description = apiDescription(pageData.relativePath);
    if (description && !pageData.frontmatter.description) {
      return {
        description,
        frontmatter: { ...pageData.frontmatter, description },
      };
    }
  },
  transformHead({ page, pageData, siteConfig, title, description }) {
    if (page === '404.md' || pageData.isNotFound) {
      return [['meta', { name: 'robots', content: 'noindex' }]];
    }
    const locale = localeOf(page);
    const key = locale === 'root' ? page : page.slice(locale.length + 1);
    const url = site + pageUrl(page);
    const exists = new Set(siteConfig.pages);
    const variants = (Object.keys(seoLocales) as SeoLocale[]).filter((l) =>
      exists.has(seoLocales[l].prefix + key)
    );
    const isHome = pageData.frontmatter.layout === 'home';
    const image = `${site}og.png`;
    const imageAlt = seoLocales[locale].imageAlt;

    const head: HeadConfig[] = [['link', { rel: 'canonical', href: url }]];
    if (variants.length > 1) {
      for (const l of variants) {
        head.push([
          'link',
          {
            rel: 'alternate',
            hreflang: seoLocales[l].lang,
            href: site + pageUrl(seoLocales[l].prefix + key),
          },
        ]);
      }
      if (variants.includes('root')) {
        head.push([
          'link',
          { rel: 'alternate', hreflang: 'x-default', href: site + pageUrl(key) },
        ]);
      }
    }
    const og: [string, string][] = [
      ['og:type', isHome ? 'website' : 'article'],
      ['og:site_name', 'React Native Waveform Player'],
      ['og:title', title],
      ['og:description', description],
      ['og:url', url],
      ['og:locale', seoLocales[locale].og],
      ...variants
        .filter((l) => l !== locale)
        .map((l): [string, string] => ['og:locale:alternate', seoLocales[l].og]),
      ['og:image', image],
      ['og:image:type', 'image/png'],
      ['og:image:width', '1200'],
      ['og:image:height', '630'],
      ['og:image:alt', imageAlt],
    ];
    for (const [property, content] of og) {
      head.push(['meta', { property, content }]);
    }
    const twitter: [string, string][] = [
      ['twitter:card', 'summary_large_image'],
      ['twitter:title', title],
      ['twitter:description', description],
      ['twitter:image', image],
      ['twitter:image:alt', imageAlt],
    ];
    for (const [name, content] of twitter) {
      head.push(['meta', { name, content }]);
    }
    return head;
  },
  locales: {
    root: {
      label: 'English',
      lang: 'en-US',
      themeConfig: themeConfig('', en),
    },
    vi: {
      label: 'Tiếng Việt',
      lang: 'vi-VN',
      title: 'React Native Waveform Player',
      description:
        'Trình phát tin nhắn thoại native cho React Native: dạng sóng có hiệu ứng, kéo để tua, nút đổi tốc độ và phát trong nền, viết bằng Swift và Kotlin.',
      themeConfig: {
        ...themeConfig('/vi', vi),
        outline: { level: [2, 3], label: 'Trên trang này' },
        docFooter: { prev: 'Trang trước', next: 'Trang sau' },
        lastUpdated: { text: 'Cập nhật lần cuối' },
        editLink: {
          pattern: `${repo}/edit/master/docs/:path`,
          text: 'Sửa trang này trên GitHub',
        },
        returnToTopLabel: 'Về đầu trang',
        sidebarMenuLabel: 'Menu',
        darkModeSwitchLabel: 'Giao diện',
        lightModeSwitchTitle: 'Chuyển sang giao diện sáng',
        darkModeSwitchTitle: 'Chuyển sang giao diện tối',
        langMenuLabel: 'Đổi ngôn ngữ',
        notFound: {
          title: 'KHÔNG TÌM THẤY TRANG',
          quote: 'Trang bạn tìm không tồn tại hoặc đã được chuyển đi.',
          linkText: 'Về trang chủ',
        },
        footer: { message: 'Phát hành theo giấy phép MIT.' },
      },
    },
    zh: {
      label: '简体中文',
      lang: 'zh-CN',
      title: 'React Native Waveform Player',
      description:
        'React Native 原生语音消息播放器：带动画的波形、拖动定位、倍速切换和后台播放，基于 Swift 与 Kotlin。',
      themeConfig: {
        ...themeConfig('/zh', zh),
        outline: { level: [2, 3], label: '页面导航' },
        docFooter: { prev: '上一页', next: '下一页' },
        lastUpdated: { text: '最后更新于' },
        editLink: {
          pattern: `${repo}/edit/master/docs/:path`,
          text: '在 GitHub 上编辑此页',
        },
        returnToTopLabel: '回到顶部',
        sidebarMenuLabel: '菜单',
        darkModeSwitchLabel: '外观',
        lightModeSwitchTitle: '切换到浅色模式',
        darkModeSwitchTitle: '切换到深色模式',
        langMenuLabel: '切换语言',
        notFound: {
          title: '页面未找到',
          quote: '你访问的页面不存在或已被移动。',
          linkText: '返回首页',
        },
        footer: { message: '基于 MIT 许可证发布。' },
      },
    },
  },
  themeConfig: {
    logo: '/logo.svg',
    socialLinks: [{ icon: 'github', link: repo }],
    search: {
      provider: 'local',
      options: {
        locales: {
          vi: {
            translations: {
              button: { buttonText: 'Tìm kiếm', buttonAriaLabel: 'Tìm kiếm' },
              modal: {
                displayDetails: 'Hiển thị chi tiết',
                resetButtonTitle: 'Xóa tìm kiếm',
                backButtonTitle: 'Đóng tìm kiếm',
                noResultsText: 'Không có kết quả cho',
                footer: {
                  selectText: 'chọn',
                  navigateText: 'di chuyển',
                  closeText: 'đóng',
                },
              },
            },
          },
          zh: {
            translations: {
              button: { buttonText: '搜索', buttonAriaLabel: '搜索' },
              modal: {
                displayDetails: '显示详情',
                resetButtonTitle: '清除查询',
                backButtonTitle: '关闭搜索',
                noResultsText: '没有找到相关结果',
                footer: {
                  selectText: '选择',
                  navigateText: '切换',
                  closeText: '关闭',
                },
              },
            },
          },
        },
      },
    },
    editLink: {
      // Serialized into the client bundle, so it cannot use variables from this file. API pages
      // are generated from the doc comments in src.
      pattern: ({ filePath }) =>
        filePath.startsWith('api/')
          ? 'https://github.com/maitrungduc1410/react-native-waveform-player/tree/master/src'
          : `https://github.com/maitrungduc1410/react-native-waveform-player/edit/master/docs/${filePath}`,
      text: 'Edit this page on GitHub',
    },
    outline: { level: [2, 3] },
    footer: { message: 'Released under the MIT License.' },
  },
});
