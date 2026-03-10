import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";
import { BrowserService } from "../../core/services/BrowserService";

@Script({
  emoji: "🧪",
  tags: ["browser", "debug", "naval"],
  args: {
    url: {
      type: "string",
      position: 0,
      required: false,
      default: "https://nav.al",
      description: "URL to test",
    },
  },
})
export class TestClickNaval extends ScriptBase {
  async run(ctx: Context): Promise<void> {
    const url = ctx.args.url as string;
    const browser = new BrowserService({ logger: this.logger });

    this.logger.banner("Test nav.al Read More");
    const initialized = await browser.initialize();
    if (!initialized) {
      throw new Error("Browser service unavailable. Install puppeteer to enable this command.");
    }

    try {
      const result = await browser.withPage(async (page) => {
        await page.goto(url, { waitUntil: "networkidle0", timeout: 60000 });
        await page.waitForTimeout(3000);

        const initialCount = await page.$$eval("a[href]", (links: Element[]) => links.length);
        const candidates = await page.$$eval("a, button, div, span", (elements: Element[]) =>
          elements
            .map((element) => ({
              text: element.textContent?.trim() || "",
              tagName: element.tagName.toLowerCase(),
              className: (element as HTMLElement).className || "",
            }))
            .filter((element) => element.text.toLowerCase().includes("read more"))
        );

        const selectorCandidates = [
          ".load-more-post-handle",
          ".trigger-load-more",
          ".extra-pagination-link",
          "[class*='load-more']",
          "[class*='read-more']",
        ];

        const selectorHits: string[] = [];
        for (const selector of selectorCandidates) {
          const hit = await page.$(selector);
          if (hit) {
            selectorHits.push(selector);
          }
        }

        let success = false;
        let finalCount = initialCount;

        for (const selector of selectorHits) {
          try {
            await page.click(selector);
          } catch {
            try {
              await page.$eval(selector, (element: Element) => {
                (element as HTMLElement).click();
              });
            } catch {
              continue;
            }
          }

          const start = Date.now();
          while (Date.now() - start < 15000) {
            await page.waitForTimeout(1000);
            finalCount = await page.$$eval("a[href]", (links: Element[]) => links.length);
            if (finalCount > initialCount) {
              success = true;
              break;
            }
          }

          if (success) {
            break;
          }
        }

        return {
          initialCount,
          finalCount,
          success,
          textCandidates: candidates.slice(0, 10),
          selectorHits,
        };
      });

      console.log(`Initial links: ${result.initialCount}`);
      console.log(`Final links: ${result.finalCount}`);
      console.log(`Success: ${result.success}`);
      console.log(`Selector hits: ${result.selectorHits.join(", ") || "none"}`);
      if (result.textCandidates.length > 0) {
        console.log("Text candidates:");
        for (const candidate of result.textCandidates) {
          console.log(`  ${candidate.tagName} ${candidate.className} -> ${candidate.text.slice(0, 80)}`);
        }
      }
    } finally {
      await browser.close();
    }
  }
}
