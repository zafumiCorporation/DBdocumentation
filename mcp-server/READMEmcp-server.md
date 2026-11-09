package.json Es la lista de recetas de Node: nombre del programa, como arrancarlo y que librerias baja npm install. 

```jsonc
{
  "name": "ai-assistant-mcp-hybrid-readonly", // nombre npm de este paquete (híbrido = archivos + BD, solo lectura)
  "version": "1.0.0", // versión tuya del servidor
  "type": "module", //Usa ESM sintaxis moderna con importy export  , Efecto todos los .js se interpretan como modulos ESM , si no se define Para usar import/export necesitas poner extension .mjs 
  "description": "MCP Server Hibrido Read-Only...", 
  "main": "dist/server.js", //Ruta del archivo que se ejecuta al arrancar tu servidor. 
  "scripts": { // Permite ejecutar comandos largos con npm run <nombre> 
    "build": "tsc", //Compila los archivos TypeScript (.ts) y genera su version Javascript en la carpeta dist/
    "start": "node dist/server.js", //Enciende el MCP: ejecuta el archivo compilado dist/server.js como servidor. 
    "dev": "tsc --watch", //Recompila automaticamente cuando cambias un archivo .ts 
    "inspector": "npx @modelcontextprotocol/inspector node dist/server.js", // Enciende el servidor y levanta el Inspecto web en el puerto 6274
    "glosa:watch": "node glosa-worker/watch.mjs",     // Observa cambios en .sql y actualiza el catalogo Glosa en tiempo real al guardar (chokidar). 
    "glosa:once": "node glosa-worker/ingest.mjs",     // una pasada: lee el repo y propone/ingiere conceptos. Aún no existe
    "glosa:lookup": "node glosa-worker/lookup.mjs",   // Permite consultar una palabra y devuelve un objeto LookupHit con su concept_id , lemma, status, stage, etc. 
    "glosa:reconcile": "node glosa-worker/reconcile.mjs" // compara catálogo vs .sql reales y actualiza estados como YA_USAS / counts o conteos de ocurrencias. Aún no existe
  },
  "dependencies": { // librerías externas que el proyecto necesita en tiempo de ejecucion. 
    "@cursor/sdk": "^1.0.31",           // API para correr agentes Cursor desde Node (scripts). 
    "@modelcontextprotocol/sdk": "^1.12.1", // protocolo MCP: tools, stdio. ESTO es lo que habla con Cursor ahora
    "ajv": "^8.20.0",                   // valida que tus objetos JSON sigan las reglas del concept.schema.json en si que mis objetos tenga los campos requeridos
    "ajv-formats": "^3.0.1",            // añade a Ajv formatos tipo "date" (updated_at)
    "chokidar": "^5.0.0",               // observa carpetas; para glosa:watch cuando un .sql cambia
    "cors": "^2.8.6",                   // HTTP: permite otras origens (si hay Express)
    "dotenv": "^16.4.5",                // lee .env (DATABASE_URL, etc.)
    "express": "^5.2.1",                // servidor HTTP (Inspector u otra API). El MCP de Cursor usa stdio, no esto
    "pg": "^8.12.0",                    // Cliente oficial de PostgreSQL para Node. Permite ejecutar consultas y conectarse a la BD
    "zod": "^3.23.8"                    // valida argumentos de cada tool en server.ts
  },
  "devDependencies": { // solo para desarrollar, no para “el bot en producción”
    "@types/cors": "...",
    "@types/express": "...",
    "@types/node": "...",
    "@types/pg": "...", // tipos TypeScript de esas librerías
    "typescript": "^5.9.3" // el compilador (npm run build)
  }
}