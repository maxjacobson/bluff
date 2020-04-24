import "./main.css";
import { Elm } from "./Main.elm";

// via https://stackoverflow.com/a/2117523
function uuidv4() {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
    var r = (Math.random() * 16) | 0,
      v = c == "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

function humanUuid() {
  const KEY = "bluff-human-uuid";
  let uuid = localStorage.getItem(KEY);

  if (!uuid) {
    uuid = uuidv4();
    localStorage.setItem(KEY, uuid);
  }

  return uuid;
}

Elm.Main.init({
  node: document.getElementById("root"),
  flags: {
    apiRoot: process.env.ELM_APP_API_ROOT || "http://localhost:3000",
    humanUuid: humanUuid(),
  },
});
