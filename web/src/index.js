import "./main.css";
import { Elm } from "./Main.elm";

Elm.Main.init({
  node: document.getElementById("root"),
  flags: {
    apiRoot: process.env.ELM_APP_API_ROOT || "http://localhost:3000",
  },
});
