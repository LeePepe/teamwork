# Visual + A11y Playwright template

Drop into any Vite/CRA/Next React (or Vue/Svelte) web repo to catch theme/contrast regressions that pure user-flow tests miss.

## Install

```bash
npm i -D @playwright/test @axe-core/playwright
npx playwright install chromium
```

Add to `package.json` scripts:

```json
"test:e2e": "playwright test",
"test:e2e:update": "playwright test --update-snapshots"
```

Add to `.gitignore` (repo root):

```
test-results/
playwright-report/
playwright/.cache/
```

Keep `tests/**/*-snapshots/` committed — those are the golden baselines.

## playwright.config.ts

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  retries: process.env.CI ? 1 : 0,
  reporter: [['list']],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:5173',
    trace: 'retain-on-failure',
    colorScheme: 'dark',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  expect: {
    toHaveScreenshot: { maxDiffPixelRatio: 0.02, animations: 'disabled' },
  },
});
```

## tests/visual.spec.ts

```ts
import { test, expect } from '@playwright/test';

const routes = [
  { name: 'home', path: '/' },
  // add one entry per top-level route
];

test.describe('visual regression', () => {
  for (const r of routes) {
    test(`${r.name} matches snapshot`, async ({ page }) => {
      await page.goto(r.path, { waitUntil: 'networkidle' });
      // Optional: theme-lock guard
      const theme = await page.evaluate(() =>
        document.documentElement.getAttribute('data-theme'));
      expect(theme).toBe('dark'); // adjust to project policy
      await page.addStyleTag({
        content: `
          [data-live-timestamp], .live-timestamp, time[data-dynamic] { visibility: hidden !important; }
          *, *::before, *::after { animation: none !important; transition: none !important; }
        `,
      });
      await expect(page).toHaveScreenshot(`${r.name}.png`, { fullPage: true });
    });
  }
});
```

## tests/a11y.spec.ts

```ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const routes = [{ name: 'home', path: '/' }];

test.describe('a11y / color-contrast', () => {
  for (const r of routes) {
    test(`${r.name} has no WCAG contrast violations`, async ({ page }) => {
      await page.goto(r.path, { waitUntil: 'networkidle' });
      const results = await new AxeBuilder({ page }).withTags(['wcag2aa']).analyze();
      const contrast = results.violations.filter(
        v => v.id === 'color-contrast' || v.id === 'color-contrast-enhanced'
      );
      if (contrast.length) {
        console.log('Contrast violations on', r.path,
          JSON.stringify(contrast.map(v => ({
            id: v.id, impact: v.impact,
            nodes: v.nodes.slice(0, 5).map(n => ({
              html: n.html.slice(0, 160), summary: n.failureSummary,
            })),
          })), null, 2));
      }
      expect(contrast).toEqual([]);
    });
  }
});

test('no lingering forbidden theme rules', async ({ page }) => {
  await page.goto('/');
  const bad = await page.evaluate(() => {
    for (const sheet of Array.from(document.styleSheets)) {
      let rules: CSSRuleList;
      try { rules = sheet.cssRules; } catch { continue; }
      for (const rule of Array.from(rules)) {
        if (rule instanceof CSSStyleRule &&
            (rule.selectorText?.includes("data-theme='light'") ||
             rule.selectorText?.includes('data-theme="light"'))) {
          return rule.selectorText;
        }
      }
    }
    return null;
  });
  expect(bad).toBeNull();
});
```

## Update baselines (explicit and reviewable)

```bash
npm run test:e2e:update
# review snapshot diffs in git before committing
```

## Why this works

- **axe contrast** catches "white on pink button" class bugs that user-flow tests never notice.
- **Visual snapshot** catches "styling system went out of sync" (CSS-vars vs hardcoded Tailwind) — exactly the class of bug where part of the page is dark and part is light.
- **Theme-lock** assertion + stylesheet scan prevents silent re-introduction of removed modes.
- All three are cheap: ~10 tests, ~3s on a laptop.
