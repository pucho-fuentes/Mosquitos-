// Servidor de corriente - puerto 3000
// Ejecutar con: node server.js   (no necesita instalar nada)

const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = 3000;
const LIMITE_AMPERIOS = 1; // si pasa de 1A -> sobrecarga
const LIMITE_TEMP = 40; // si pasa de 40 C -> temperatura alta
const ARCHIVO = path.join(__dirname, "datos.json");

// Cargar datos guardados (si existen)
let datos = [];
try {
  datos = JSON.parse(fs.readFileSync(ARCHIVO, "utf8"));
} catch (e) {
  datos = [];
}

function guardar() {
  fs.writeFileSync(ARCHIVO, JSON.stringify(datos, null, 2));
}

function responderJSON(res, codigo, obj) {
  res.writeHead(codigo, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(obj));
}

const server = http.createServer((req, res) => {
  const url = req.url.split("?")[0];

  // POST /corriente -> recibe datos  {"corriente": 0.85}
  if (url === "/corriente" && req.method === "POST") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        const json = JSON.parse(body);
        const corriente = Number(json.corriente);
        if (Number.isNaN(corriente)) {
          return responderJSON(res, 400, { error: "'corriente' debe ser un numero" });
        }

        // acepta "temperatura", "temp" o "temperature"
        const tRaw =
          json.temperatura !== undefined ? json.temperatura
          : json.temp !== undefined ? json.temp
          : json.temperature;
        const temperatura =
          tRaw === undefined || tRaw === null || tRaw === "" ? null : Number(tRaw);
        if (temperatura !== null && Number.isNaN(temperatura)) {
          return responderJSON(res, 400, { error: "'temperatura' debe ser un numero" });
        }

        const sobrecarga = corriente > LIMITE_AMPERIOS;
        const tempAlta = temperatura !== null && temperatura > LIMITE_TEMP;
        const registro = {
          corriente,
          temperatura,
          fecha: new Date().toISOString(),
          sobrecarga,
          tempAlta,
        };
        datos.push(registro);
        if (datos.length > 5000) datos.shift(); // limite para no crecer infinito
        guardar();

        let mensaje = "Consumo normal";
        if (sobrecarga) mensaje = "Hubo un pico de sobrecarga";
        if (tempAlta) mensaje += " | Temperatura alta";
        const t = temperatura !== null ? " / " + temperatura + " C" : "";
        console.log(
          (sobrecarga || tempAlta ? "[ALERTA] " : "[OK] ") + corriente + " A" + t
        );
        responderJSON(res, 200, { ok: true, mensaje, ...registro });
      } catch (e) {
        responderJSON(res, 400, { error: "JSON invalido" });
      }
    });
    return;
  }

  // GET /corriente -> devuelve todos los datos
  if (url === "/corriente" && req.method === "GET") {
    return responderJSON(res, 200, datos);
  }

  // GET /graficas -> pagina HTML con la grafica
  if (url === "/graficas" && req.method === "GET") {
    fs.readFile(path.join(__dirname, "graficas.html"), (err, html) => {
      if (err) {
        res.writeHead(500);
        return res.end("No se encontro graficas.html");
      }
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      res.end(html);
    });
    return;
  }

  responderJSON(res, 404, { error: "Ruta no encontrada" });
});

server.listen(PORT, "0.0.0.0", () => {
  console.log("Servidor (version con temperatura) en http://localhost:" + PORT);
  console.log("  POST /corriente  -> recibir datos");
  console.log("  GET  /graficas   -> ver grafica");
});