import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import ChatICAppProvider from "./chatSDK/chatAppContext";

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <ChatICAppProvider>
      <App />
    </ChatICAppProvider>
  </React.StrictMode>
);
