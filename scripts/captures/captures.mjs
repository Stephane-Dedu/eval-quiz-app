// Captures d'écran du parcours complet, exécutées par scripts/captures.sh dans
// l'image Playwright officielle.
//
// Parcours : inscription → Questions jusqu'à la fin → Résultat enregistré →
// connexion Administrateur → tableau des Résultats.
// Les erreurs de la console (dont les violations de la politique CSP) sont
// consignées dans console.txt : le fichier doit rester vide.

import { writeFileSync } from "node:fs";
import { chromium } from "playwright";

const BASE_URL = (process.env.BASE_URL ?? "").replace(/\/$/, "");
const OUT = process.env.OUT ?? "/out";
const SUBJECT = process.env.SUBJECT ?? "docker";
const { ADMIN_USERNAME, ADMIN_PASSWORD } = process.env;
if (!BASE_URL || !ADMIN_USERNAME || !ADMIN_PASSWORD) {
  throw new Error("BASE_URL, ADMIN_USERNAME et ADMIN_PASSWORD sont requis");
}

const consoleErrors = [];
// En HTTP (local), Chrome ignore Cross-Origin-Opener-Policy hors de
// « localhost ». On lui fait traiter l'origine comme sécurisée, comme le sera
// l'HTTPS de Container Apps, pour vérifier aussi cet en-tête.
const origin = new URL(BASE_URL).origin;
const browser = await chromium.launch({
  args: origin.startsWith("http://") ? [`--unsafely-treat-insecure-origin-as-secure=${origin}`] : [],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 860 }, locale: "fr-FR" });
page.on("console", (msg) => {
  if (msg.type() === "error") consoleErrors.push(`[console] ${msg.text()}`);
});
page.on("pageerror", (err) => consoleErrors.push(`[page] ${err.message}`));

const shot = async (name) => {
  await page.screenshot({ path: `${OUT}/${name}.png`, fullPage: true });
  console.log(`capture ${name}.png`);
};

// 1. Inscription
await page.goto(BASE_URL);
await page.locator("#registration-form").waitFor();
await page.fill("#firstname", "Démo");
await page.fill("#email", `demo-${Date.now()}@example.com`);
await page.fill("#subject", SUBJECT);
await shot("01-inscription");
await page.click("#registration-form button");

// 2. Questions : on choisit toujours le premier Choix
const nextStep = page.locator('input[name="answer"]:not([disabled]), h1:has-text("Bravo")').first();
for (let index = 0; ; index++) {
  await nextStep.waitFor({ timeout: 45_000 });
  if (await page.locator('h1:has-text("Bravo")').count()) break;
  if (index === 0) await shot("02-question");
  await page.locator('input[name="answer"]').first().check();
  await page.locator("#app button", { hasText: "Valider" }).click();
  if (index === 0) await shot("03-correction");
  await page.locator("#app button", { hasText: "Suivant" }).click();
}

// 3. Résultat enregistré
await page.locator(".saving-message.success, .saving-message.error").waitFor({ timeout: 15_000 });
await shot("04-resultat");

// 4. Administration
await page.goto(`${BASE_URL}/gestion-quiz`);
await page.locator("#login-form").waitFor();
await shot("05-connexion-administrateur");
await page.fill("#username", ADMIN_USERNAME);
await page.fill("#password", ADMIN_PASSWORD);
await page.click("#login-form button");
await page.locator("#results-body tr").first().waitFor({ timeout: 15_000 });
await shot("06-tableau-administrateur");

await browser.close();

writeFileSync(`${OUT}/console.txt`, consoleErrors.join("\n") + (consoleErrors.length ? "\n" : ""));
console.log(consoleErrors.length ? `${consoleErrors.length} erreur(s) en console` : "aucune erreur en console");
process.exit(consoleErrors.length ? 1 : 0);
