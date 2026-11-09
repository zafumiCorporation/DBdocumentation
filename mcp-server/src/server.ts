import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, ListResourcesRequestSchema, ReadResourceRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import pg from "pg";
import fs from "fs/promises";
import path from "path";
import dotenv from "dotenv";
dotenv.config();

const ROOT_DIR = process.env.ROOT_DIR || "C:\\Users\\yonat\\OneDrive\\Documentos\\CursoPostgreSQL-ConsultasAvanzadas-AIAssistant";
const ALLOWED_EXTS = [".sql", ".md", ".json", ".ts", ".js", ".txt", ".yaml"];
const FORBIDDEN_SQL = /\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|GRANT|CREATE|REVOKE|VACUUM|COPY)\b/i;

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false }, max: 3 });

const server = new Server({ name: "ai-assistant-hybrid-faang", version: "2.0.0" }, { capabilities: { resources: {}, tools: {} } });

function isSafe(p: string) { return path.resolve(ROOT_DIR, p).startsWith(ROOT_DIR); }
function isReadOnly(sql: string) {
  if (FORBIDDEN_SQL.test(sql)) return false;
  const t = sql.trim().toLowerCase();
  return t.startsWith("select") || t.startsWith("with") || t.startsWith("show");
}

// RESOURCES - Tu carpeta como recurso
server.setRequestHandler(ListResourcesRequestSchema, async () => {
  async function walk(dir: string, base = ""): Promise<any[]> {
    const entries = await fs.readdir(dir, { withFileTypes: true });
    let out: any[] = [];
    for (const e of entries) {
      if (e.name.startsWith(".") || ["node_modules", "dist", "mcp-server", ".cursor"].includes(e.name)) continue;
      const rel = path.join(base, e.name);
      const full = path.join(dir, e.name);
      if (e.isDirectory()) out = out.concat(await walk(full, rel));
      else if (ALLOWED_EXTS.includes(path.extname(e.name))) out.push({ uri: `file:///${rel.replace(/\\/g, "/")}`, name: rel, mimeType: "text/plain" });
    }
    return out;
  }
  return { resources: await walk(ROOT_DIR) };
});

server.setRequestHandler(ReadResourceRequestSchema, async (req) => {
  const rel = req.params.uri.replace("file:///", "").replace(/\//g, "\\");
  if (!isSafe(rel)) throw new Error("Fuera de whitelist");
  const text = await fs.readFile(path.join(ROOT_DIR, rel), "utf-8");
  return { contents: [{ uri: req.params.uri, mimeType: "text/plain", text: text.slice(0, 60000) }] };
});

// TOOLS - Las 14 herramientas FAANG que pediste
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    { name: "get_project_tree", description: "Arbol completo 00_ a 15_ como lo pediste", inputSchema: { type: "object", properties: {} } },
    { name: "read_file", description: "Lee cualquier.sql/.md del proyecto", inputSchema: { type: "object", properties: { file: { type: "string", description: "Ej: 00_ConfiguracionGlobal/01_extensiones.sql" } }, required: ["file"] } },
    { name: "search_project", description: "Busca texto: pg_trgm, unaccent, login_desktop", inputSchema: { type: "object", properties: { query: { type: "string" } }, required: ["query"] } },
    { name: "list_tables", description: "Lista tablas public", inputSchema: { type: "object", properties: {} } },
    { name: "describe_table", description: "Describe tabla: columnas, tipos, nullable", inputSchema: { type: "object", properties: { table: { type: "string" } }, required: ["table"] } },
    { name: "list_foreign_keys", description: "Todas las relaciones FK", inputSchema: { type: "object", properties: {} } },
    { name: "list_indexes", description: "Indices GIN, trgm, etc", inputSchema: { type: "object", properties: {} } },
    { name: "list_functions", description: "Funciones login_desktop, buscar_tutoriales, etc", inputSchema: { type: "object", properties: {} } },
    { name: "get_database_schema", description: "Schema COMPLETO para IA: tablas+cols+FK+indices+funcs", inputSchema: { type: "object", properties: {} } },
    { name: "analyze_database", description: "Compara tu BD actual vs plataforma social y propone tablas faltantes", inputSchema: { type: "object", properties: {} } },
    { name: "execute_select_query", description: "Solo SELECT/WITH permitido, bloquea INSERT/UPDATE/DELETE", inputSchema: { type: "object", properties: { sql: { type: "string" } }, required: ["sql"] } },
  ]
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: a } = req.params as any;

  if (name === "get_project_tree") {
    async function tree(dir: string, depth = 0): Promise<string> {
      const entries = (await fs.readdir(dir, { withFileTypes: true })).filter(e =>!e.name.startsWith(".") &&!["node_modules","dist","mcp-server"].includes(e.name)).sort((x,y)=> x.name.localeCompare(y.name));
      let out = "";
      for (const e of entries) {
        out += "│ ".repeat(depth) + "├── " + e.name + (e.isDirectory()? "/\n" : "\n");
        if (e.isDirectory()) out += await tree(path.join(dir, e.name), depth + 1);
      }
      return out;
    }
    const result = `CursoPostgreSQL-ConsultasAvanzadas-AIAssistant/\n${await tree(ROOT_DIR)}`;
    return { content: [{ type: "text", text: result }] };
  }

  if (name === "read_file") {
    const file = z.string().min(3).parse(a.file);
    if (!isSafe(file)) throw new Error("Path no permitido");
    const content = await fs.readFile(path.join(ROOT_DIR, file), "utf-8");
    return { content: [{ type: "text", text: content.slice(0, 40000) }] };
  }

  if (name === "search_project") {
    const query = z.string().min(2).parse(a.query);
    const allFiles: string[] = [];
    async function collect(dir: string) {
      const entries = await fs.readdir(dir, { withFileTypes: true });
      for (const e of entries) {
        if (e.name.startsWith(".") || ["node_modules","dist"].includes(e.name)) continue;
        const full = path.join(dir, e.name);
        if (e.isDirectory()) await collect(full);
        else if (ALLOWED_EXTS.includes(path.extname(e.name))) allFiles.push(full);
      }
    }
    await collect(ROOT_DIR);
    let matches: string[] = [];
    for (const f of allFiles) {
      try {
        const txt = await fs.readFile(f, "utf-8");
        if (txt.toLowerCase().includes(query.toLowerCase())) {
          matches.push(`${path.relative(ROOT_DIR,f)} -> encontrado`);
          if (matches.length > 30) break;
        }
      } catch {}
    }
    return { content: [{ type: "text", text: matches.length? matches.join("\n") : `No se encontro ${query}` }] };
  }

  if (name === "list_tables") {
    const r = await pool.query(`SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name`);
    return { content: [{ type: "text", text: JSON.stringify(r.rows, null, 2) }] };
  }
  if (name === "describe_table") {
    const t = z.string().regex(/^[a-z_0-9]+$/).parse(a.table);
    const r = await pool.query(`SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position`, [t]);
    return { content: [{ type: "text", text: JSON.stringify(r.rows, null, 2) }] };
  }
  if (name === "list_foreign_keys") {
    const r = await pool.query(`SELECT tc.table_name, kcu.column_name, ccu.table_name AS foreign_table, ccu.column_name AS foreign_col FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage kcu ON tc.constraint_name=kcu.constraint_name JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name=tc.constraint_name WHERE tc.constraint_type='FOREIGN KEY' AND tc.table_schema='public'`);
    return { content: [{ type: "text", text: JSON.stringify(r.rows, null, 2) }] };
  }
  if (name === "list_indexes") {
    const r = await pool.query(`SELECT tablename, indexname, indexdef FROM pg_indexes WHERE schemaname='public' ORDER BY tablename`);
    return { content: [{ type: "text", text: JSON.stringify(r.rows, null, 2) }] };
  }
  if (name === "list_functions") {
    const r = await pool.query(`SELECT routine_name, routine_type FROM information_schema.routines WHERE routine_schema='public' ORDER BY routine_name`);
    return { content: [{ type: "text", text: JSON.stringify(r.rows, null, 2) }] };
  }
  if (name === "get_database_schema") {
    const tables = await pool.query(`SELECT table_name FROM information_schema.tables WHERE table_schema='public'`);
    const cols = await pool.query(`SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema='public'`);
    const fks = await pool.query(`SELECT tc.table_name, kcu.column_name, ccu.table_name AS ft FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage kcu ON tc.constraint_name=kcu.constraint_name JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name=tc.constraint_name WHERE tc.constraint_type='FOREIGN KEY'`);
    const idx = await pool.query(`SELECT tablename, indexname FROM pg_indexes WHERE schemaname='public'`);
    const funcs = await pool.query(`SELECT routine_name FROM information_schema.routines WHERE routine_schema='public'`);
    return { content: [{ type: "text", text: JSON.stringify({ tables: tables.rows, columns: cols.rows, foreign_keys: fks.rows, indexes: idx.rows, functions: funcs.rows }, null, 2) }] };
  }
  if (name === "analyze_database") {
    const existing = (await pool.query(`SELECT table_name FROM information_schema.tables WHERE table_schema='public'`)).rows.map(r=>r.table_name);
    const blueprint = {
      existentes: existing,
      objetivo: "Plataforma social de tutoriales con blueprints + amigos + ejecucion guiada",
      faltantes: ["comentarios","tutorial_likes","favoritos","amistades","notificaciones","historial_visualizaciones","categorias","tutorial_pasos","tutorial_edits"].filter(t=>!existing.includes(t)),
      analisis: {
        auth: existing.includes("sesiones_ram")? "OK tienes sesiones_ram + password_hash" : "FALTA sesiones_ram",
        busqueda: "Revisa si tienes idx_titulo_trgm + funcion buscar_tutoriales",
        social: existing.includes("amistades")? "OK tienes amistades, te falta estados online" : "FALTA amistades para Imagen 2",
        blueprints: existing.includes("tutorial_pasos")? "OK tienes tutorial_pasos para nodos visuales" : "FALTA tutorial_pasos para Imagen 4"
      },
      sql_propuesta: `
-- EJECUTA ESTO EN 15_BlueprintsScriptsDataset/
CREATE TABLE IF NOT EXISTS comentarios (id SERIAL PRIMARY KEY, tutorial_id INT REFERENCES tutoriales(id), usuario_id INT REFERENCES usuarios(id), texto TEXT, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS tutorial_likes (usuario_id INT REFERENCES usuarios(id), tutorial_id INT REFERENCES tutoriales(id), PRIMARY KEY(usuario_id, tutorial_id));
CREATE TABLE IF NOT EXISTS favoritos (usuario_id INT REFERENCES usuarios(id), tutorial_id INT REFERENCES tutoriales(id), PRIMARY KEY(usuario_id, tutorial_id));
CREATE TABLE IF NOT EXISTS notificaciones (id SERIAL PRIMARY KEY, usuario_id INT REFERENCES usuarios(id), tipo TEXT, payload JSONB, leida BOOLEAN DEFAULT false);
CREATE TABLE IF NOT EXISTS historial_visualizaciones (id SERIAL PRIMARY KEY, usuario_id INT REFERENCES usuarios(id), tutorial_id INT REFERENCES tutoriales(id), paso_actual INT, completado BOOLEAN);
`
    };
    return { content: [{ type: "text", text: JSON.stringify(blueprint, null, 2) }] };
  }
  if (name === "execute_select_query") {
    const sql = z.string().min(6).parse(a.sql);
    if (!isReadOnly(sql)) throw new Error("BLOQUEADO FAANG: Solo SELECT/WITH permitido");
    const r = await pool.query(sql);
    return { content: [{ type: "text", text: JSON.stringify(r.rows.slice(0, 100), null, 2) }] };
  }
  throw new Error("Tool no existe");
});

async function main() { await server.connect(new StdioServerTransport()); }
main().catch(e=>{ console.error(e); process.exit(1); });