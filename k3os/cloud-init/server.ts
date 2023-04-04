import {
  Application,
  Router,
  Context,
} from "https://deno.land/x/oak@v12.1.0/mod.ts";
import * as path from "https://deno.land/std@0.138.0/path/mod.ts";

const port = Number(Deno.env.get("PORT") ?? "3000");
const router = new Router();

router.get("/kairos", async (ctx: Context) => {
  ctx.response.body = await loadText("./kairos-server.yaml");
});
router.get("/k3os", async (ctx: Context) => {
  ctx.response.body = await loadText("./k3os-server.yaml");
});

const app = new Application();
app.use(router.routes());
app.use(router.allowedMethods());

console.log(`Serving on http://localhost:${port}/`);
app.listen({ port });

async function loadText(file: string): Promise<string> {
  const password = Deno.env.get("K3OS_PASSWORD");
  if (!password) throw new Error("Missing K3OS_PASSWORD");
  const text = await Deno.readTextFile(
    path.resolve(path.dirname(path.fromFileUrl(import.meta.url)), file)
  );
  return text.replace("$$PASSWORD", password);
}
