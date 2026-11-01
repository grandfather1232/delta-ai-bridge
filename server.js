const http = require("http");

const PORT = process.env.PORT || 3000;
const TOKEN = process.env.DELTA_TOKEN;
const CLIENT = process.env.CLIENT_TOKEN;

let queue = [];

const allowed = ["scan_npcs", "attack_next", "stop"];

const html = `<!DOCTYPE html>
<html lang="ru">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Delta AI Control</title>
<style>
body{background:#111;color:white;font-family:Arial;padding:20px}
main{max-width:420px;margin:auto}
input,button{width:100%;padding:15px;margin:7px 0;
box-sizing:border-box;border-radius:10px;font-size:16px}
input{background:#222;color:white;border:1px solid #555}
button{background:#673de6;color:white;border:0}
.stop{background:#b83232}
#status{color:#aaa;margin-top:15px}
</style>
<main>
<h2>Delta Control</h2>
<p>Подключение к твоей игре</p>
<input id="key" type="password" placeholder="DELTA_TOKEN">
<button onclick="save()">Подключиться</button>
<hr>
<button onclick="send('scan_npcs')">Найти NPC</button>
<button onclick="send('attack_next')">Начать фарм</button>
<button class="stop" onclick="send('stop')">СТОП</button>
<div id="status">Ожидание подключения</div>
</main>
<script>
let token="";
function save(){
 token=document.getElementById("key").value;
 document.getElementById("status").textContent=
 token ? "Ключ введён" : "Введи ключ";
}
async function send(action){
 if(!token){alert("Сначала введи DELTA_TOKEN");return}
 try{
  const r=await fetch("/command",{
   method:"POST",
   headers:{"Content-Type":"application/json","x-api-key":token},
   body:JSON.stringify({action})
  });
  const d=await r.json();
  document.getElementById("status").textContent=
   r.ok ? "Команда отправлена: "+action : "Ошибка: "+d.error;
 }catch(e){
  document.getElementById("status").textContent="Ошибка соединения";
 }
}
</script>
</html>`;

const server = http.createServer((req, res) => {
  const send = (code, data) => {
    res.writeHead(code, {"Content-Type":"application/json"});
    res.end(JSON.stringify(data));
  };

  if (req.url === "/health" && req.method === "GET")
    return send(200, {status:"online"});

  if (req.url === "/panel" && req.method === "GET") {
    res.writeHead(200, {"Content-Type":"text/html; charset=utf-8"});
    return res.end(html);
  }

  if (req.url === "/command" && req.method === "POST") {
    if (!TOKEN || req.headers["x-api-key"] !== TOKEN)
      return send(401, {error:"Unauthorized"});

    let body = "";
    req.on("data", chunk => body += chunk);
    req.on("end", () => {
      try {
        const data = JSON.parse(body);
        if (!allowed.includes(data.action))
          return send(400, {error:"Unknown action"});
        queue.push({action:data.action});
        send(200, {accepted:true});
      } catch {
        send(400, {error:"Invalid JSON"});
      }
    });
    return;
  }

  if (req.url === "/next" && req.method === "GET") {
    if (!CLIENT || req.headers["x-api-key"] !== CLIENT)
      return send(401, {error:"Unauthorized"});
    return send(200, {command:queue.shift() || null});
  }

  send(404, {error:"Not found"});
});

server.listen(PORT, () => {
  console.log("Delta bridge is running on port " + PORT);
});





