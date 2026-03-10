import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";
import { BrowserService } from "../../core/services/BrowserService";

@Script({
  emoji: "🔍",
  tags: ["browser", "debug", "naval"],
  args: {
    url: {
      type: "string",
      position: 0,
      required: false,
      default: "https://nav.al",
      description: "URL to inspect",
    },
  },
})
export class InvestigateNavalJs extends ScriptBase {
  async run(ctx: Context): Promise<void> {
    const url = ctx.args.url as string;
    const browser = new BrowserService({ logger: this.logger });

    this.logger.banner("Investigate nav.al JavaScript");
    const initialized = await browser.initialize();
    if (!initialized) {
      throw new Error("Browser service unavailable. Install puppeteer to enable this command.");
    }

    try {
      const report = await browser.withPage(async (page) => {
        await page.goto(url, { waitUntil: "networkidle0", timeout: 60000 });
        await page.waitForTimeout(5000);

        const beforeHeight = await page.evaluate(() => document.body.scrollHeight);
        const initialLinks = await page.$$eval("a[href]", (links: Element[]) => links.length);
        const triggerPresent = await page.$(".trigger-load-more");

        let triggerDetails = null;
        if (triggerPresent) {
          triggerDetails = await page.$eval(".trigger-load-more", (element: Element) => ({
            text: element.textContent?.trim() || "",
            className: (element as HTMLElement).className || "",
            href: (element as HTMLAnchorElement).getAttribute("href") || "",
            onclick: (element as HTMLAnchorElement).getAttribute("onclick") || "",
            dataAttributes: Array.from(element.attributes)
              .filter((attribute) => attribute.name.startsWith("data-"))
              .reduce<Record<string, string>>((acc, attribute) => {
                acc[attribute.name] = attribute.value;
                return acc;
              }, {}),
          }));

          await page.$eval(".trigger-load-more", (element: Element) => {
            (element as HTMLElement).scrollIntoView({ behavior: "auto", block: "center" });
          });
          await page.waitForTimeout(1500);
        }

        await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
        await page.waitForTimeout(3000);

        const afterHeight = await page.evaluate(() => document.body.scrollHeight);
        const afterScrollLinks = await page.$$eval("a[href]", (links: Element[]) => links.length);

        let clickEffects = {
          mouseEvents: "",
          keyboardEvent: false,
          linkCountAfterClick: afterScrollLinks,
          potentialFunctions: [] as string[],
        };

        if (triggerPresent) {
          clickEffects = await page.$eval(".trigger-load-more", (element: Element) => {
            const target = element as HTMLElement;
            const mouseEvents = ["mousedown", "mouseup", "click"]
              .map((type) => {
                const event = new MouseEvent(type, {
                  bubbles: true,
                  cancelable: true,
                  view: window,
                  button: 0,
                });
                return `${type}:${target.dispatchEvent(event)}`;
              })
              .join(", ");

            target.focus();
            const keyboardEvent = target.dispatchEvent(
              new KeyboardEvent("keydown", {
                key: "Enter",
                code: "Enter",
                keyCode: 13,
                bubbles: true,
                cancelable: true,
              })
            );

            const potentialFunctions = Object.keys(window).filter((key) => {
              const value = (window as Record<string, unknown>)[key];
              return (
                typeof value === "function" &&
                ["load", "more", "next"].some((token) => key.toLowerCase().includes(token))
              );
            });

            return {
              mouseEvents,
              keyboardEvent,
              linkCountAfterClick: document.querySelectorAll("a[href]").length,
              potentialFunctions,
            };
          });
        }

        const libraries = await page.evaluate(() => ({
          jqueryVersion:
            typeof (window as any).jQuery !== "undefined" ? (window as any).jQuery.fn.jquery : "not loaded",
          dollarAvailable: typeof (window as any).$ !== "undefined",
        }));

        return {
          url,
          initialLinks,
          beforeHeight,
          afterHeight,
          afterScrollLinks,
          triggerDetails,
          libraries,
          clickEffects,
        };
      });

      console.log(`URL: ${report.url}`);
      console.log(`jQuery: ${report.libraries.jqueryVersion}`);
      console.log(`$ available: ${report.libraries.dollarAvailable}`);
      console.log(`Initial links: ${report.initialLinks}`);
      console.log(`Scroll height: ${report.beforeHeight} -> ${report.afterHeight}`);
      console.log(`Links after scroll: ${report.afterScrollLinks}`);
      if (report.triggerDetails) {
        console.log("Trigger details:");
        console.log(`  Text: ${report.triggerDetails.text}`);
        console.log(`  Class: ${report.triggerDetails.className}`);
        console.log(`  Href: ${report.triggerDetails.href || "none"}`);
        console.log(`  OnClick: ${report.triggerDetails.onclick || "none"}`);
        console.log(`  Data: ${JSON.stringify(report.triggerDetails.dataAttributes)}`);
        console.log(`Mouse events: ${report.clickEffects.mouseEvents}`);
        console.log(`Keyboard event: ${report.clickEffects.keyboardEvent}`);
        console.log(`Links after click simulation: ${report.clickEffects.linkCountAfterClick}`);
        console.log(`Potential global functions: ${report.clickEffects.potentialFunctions.join(", ") || "none"}`);
      } else {
        console.log("No .trigger-load-more element found.");
      }
    } finally {
      await browser.close();
    }
  }
}
