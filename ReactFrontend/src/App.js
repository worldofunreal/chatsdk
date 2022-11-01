import React, { useContext, useEffect, useState } from 'react';
import Unity, { UnityContext } from "react-unity-webgl";
import { ChatAppContext } from "./chatSDK/chatAppContext";
import "./styles/main.css";

const unityContext = new UnityContext({
  loaderUrl: "GameBuild/Build/GameBuild.loader.js",
  dataUrl: "GameBuild/Build/GameBuild.data",
  frameworkUrl: "GameBuild/Build/GameBuild.framework.js",
  codeUrl: "GameBuild/Build/GameBuild.wasm",
});

function App() {

  let { setUnityApp } = useContext(ChatAppContext);

  useEffect(() => {
    setUnityApp(unityContext);
  }, []);

  return (
    <>
      <Unity 
        unityContext={unityContext} 
        style={{
          height: "auto",
          width: "100%",
        }} 
      />
    </>
  );
}

export default App;
