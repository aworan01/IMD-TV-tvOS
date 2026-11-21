const endpoint = "https://YOUR-WORKER.workers.dev";
const provider = document.querySelector("#provider"), m3u = document.querySelector("#m3u"), xtream = document.querySelector("#xtream");
provider.onchange = () => { const isM3U = provider.value === "M3U Playlist"; m3u.hidden = !isM3U; xtream.hidden = isM3U; };
document.querySelector("#form").onsubmit = async event => {
  event.preventDefault(); const status = document.querySelector("#status"); status.value = "Sending…";
  const value = id => document.querySelector(`#${id}`).value || null;
  const payload = { provider: provider.value, name: value("name"), serverURL: value("serverURL"), playlistURL: value("playlistURL"), epgURL: value("epgURL"), username: value("username"), password: value("password") };
  try { const response = await fetch(`${endpoint}/pair/${value("code").toUpperCase()}`, { method:"PUT", headers:{"content-type":"application/json"}, body:JSON.stringify(payload) });
    if (!response.ok) throw new Error(response.status === 404 ? "That code expired or was not found." : "The playlist could not be sent.");
    status.value = "Playlist sent. Return to your Apple TV.";
  } catch (error) { status.value = error.message; }
};

