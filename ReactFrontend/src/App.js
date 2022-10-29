import React, { useState, useEffect } from 'react';
import { StoicIdentity } from "ic-stoic-identity";
import { Actor, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { idlFactory as coreCanisterIDL } from './canisters/core';
import { idlFactory as chatCanisterIDL } from './canisters/public_group';
import Unity, { UnityContext } from "react-unity-webgl";
import "./styles/main.css";

const unityContext = new UnityContext({
  loaderUrl: "GameBuild/Build/GameBuild.loader.js",
  dataUrl: "GameBuild/Build/GameBuild.data",
  frameworkUrl: "GameBuild/Build/GameBuild.framework.js",
  codeUrl: "GameBuild/Build/GameBuild.wasm",
});

function App() {
  /// To integrate the chat you'll need the following:
  const [identity,         setIdentity]         = useState(null); /// An identity of the user logged in
  const [chatCoreCanister, setChatCoreCanister] = useState(null); /// The canister of the chat
  const [userGroups,       setUserGroups]       = useState(null); /// The user's groups list
  const [chatSelected,     setChatSelected]     = useState(null); /// The chat selected
  const [chatCanister,     setChatCanister]     = useState(null); /// The canister of the selected chat
  const [chatText,         setChatText]         = useState(null); /// The text in the selected chat

  /// The IC's host URL
  const host = 'https://raw.ic0.app/';
  /// The Chat canisterId
  const coreCanisterId = "2nfjo-7iaaa-aaaag-qawaq-cai";
  
  useEffect(() => {
    if(identity !== null) {
      /// When an identity is set, get the Chat canister
      setCoreCanister();
    }
  }, [identity]);

  useEffect(() => {
    if(chatCoreCanister !== null){
      /// When the canister is set, get the user's data
      loginUser();
    }
  }, [chatCoreCanister]);

  useEffect(() => {
    if(userGroups !== null){
      // When the user is set, show the list of groups they belong to
      renderGroupsList();
    }
  }, [userGroups]);

  useEffect(() => {
    if(chatSelected !== null){
      /// When the user selects a group, get it's data
      getChatData();
    }
  }, [chatSelected]);

  useEffect(() => {
    if(chatText !== null){
      /// Send the messages to Unity
    }
    renderChatMessages();
  }, [chatText]);

  useEffect(() => {
    /// Unity has problems to paste into inputs on webgl, so we handle it on react
    const handlePasteAnywhere = event => {
      let _txt = event.clipboardData.getData('text');
      console.log(_txt);
      unityContext.send("ChatManager", "getPaste", _txt);
    };

    window.addEventListener('paste', handlePasteAnywhere);

    return () => {
      window.removeEventListener('paste', handlePasteAnywhere);
    };
  }, []);

  /// Connections to Unity
  unityContext.on("Login", () => {
    loginStoic();
  });

  unityContext.on("CreateUser", (name) => {
    createNewUser(name);
  });

  unityContext.on("SendMessage", (text) => {
    sendMessage(text);
  });

  unityContext.on("AddUserToGroup", (json) => {
    addUserToGroup(json);
  });

  unityContext.on("CreateGroup", (groupName) => {
    createGroup(groupName);
  });

  unityContext.on("SelectChatGroup", (groupID) => {
    selectChat(groupID);
  });

  /// STOIC IDENTITY
  const loginStoic = async () => {
    let _stoicIdentity = await StoicIdentity.load().then(async identity => {
      if (identity !== false) {
        //ID is a already connected wallet!
      } else {
        //No existing connection, lets make one!
        identity = await StoicIdentity.connect();
      }
      return identity;
    });
    setIdentity(_stoicIdentity);
  };

  const setCanister = async (idl, canisterId) => {
    /// Code to set a canister requiring idl and the canister id as text
    const _canister = Actor.createActor(idl, {
      agent: new HttpAgent({
        host: host,
        identity,
      }),
      canisterId,
    });
    return _canister;
  };

  const setCoreCanister = async () => {
    ///Get the main canister
    setChatCoreCanister(await setCanister(coreCanisterIDL, coreCanisterId));
  };

  const loginUser = async () => {
    /// Get user if exists
    let _user = await chatCoreCanister.get_user(identity.getPrincipal());
    if(_user === null || _user === [] || _user.length <= 0){
      /// Create new user, send request to ask for user's name from Unity
      unityContext.send("ChatManager", "SetNewUser", "");
    } else {
      /// Already created, set the data and get the user's groups
      let _userGroups = await chatCoreCanister.get_user_groups();
      setUserGroups(_userGroups[0].groups);
      let _publicChat = _userGroups[0].groups[0]
      setChatSelected(_publicChat);
      unityContext.send("ChatManager", "Initialize", "");
      setTimeout(() => {
        getUserGroups();
      }, 2000);
    }
  };

  const createNewUser = async (name) => {
    if(name.trim() === ""){
      alert("Select a valid username");
      return false;
    }
    /// Create user with signed accound and selected username
    let _newUser = await chatCoreCanister.create_user_profile(name);
    /// After creating the user we can login as normal
    loginUser();
  };

  const renderGroupsList = () => {
    /// Once we have all user's groups we can display them
    let _userGroups = userGroups;
    /// First we sort them by ID asc
    _userGroups.sort((a, b) => { return (parseInt(a.groupID) - parseInt(b.groupID)) });
    let _groupsUnity = [];
    /// Then we prepare the data for Unity3D
    /// The data needs to be on an array and each registry needs to have id and name
    for(let i = 0; i < _userGroups.length; i++){
      let _group = {
        id:   parseInt(_userGroups[i].groupID),
        name: _userGroups[i].name
      };
      _groupsUnity.push(_group);
    }
    /// After we have the array, it needs to be encapsuled into another json to be processed inside Unity3D
    _groupsUnity = "{\"data\":" + JSON.stringify(_groupsUnity) + "}";
    unityContext.send("ChatManager", "GetGroups", _groupsUnity);
    /// After all data has been send, we set a timeout to continue to query new data
    setTimeout(() => {
      updateChatData();
    }, 3000);
  };

  const getChatData = async () => {
    unityContext.send("ChatManager", "ClearMessages", "");
    let _chatCanister = await setCanister(chatCanisterIDL, chatSelected.canister);
    setChatCanister(_chatCanister);
    let _chatData = await _chatCanister.get_messages();
    if(_chatData !== null){
      setChatText(_chatData);
    }
  };

  const updateChatData = async () => {
    let _chatData = await chatCanister.get_messages();
    setChatText(_chatData);
  };

  const sendMessage = async (message) => {
    if(message.trim() !== ""){
      let _send = await chatCanister.add_text_message(message);
      //updateChatData();
    }
  };

  const selectChat = async (groupID) => {
    for(let i = 0; i < userGroups.length; i++){
      console.log(userGroups[i]);
      if(parseInt(userGroups[i].groupID) === groupID){
        setChatSelected(userGroups[i]);
        return true;
      }
    }
    return false;
  };

  const renderChatMessages = () => {
    let _chatText = chatText;
    let _msgUnity = [];
    if(_chatText !== null){
      _chatText.sort((a, b) => { return (parseInt(a[0]) - parseInt(b[0])) });
      for(let i = 0; i < _chatText.length; i++){
        let _msg = {
          id:   parseInt(_chatText[i][0]),
          text: _chatText[i][1].username + ": " + _chatText[i][1].text
        };
        _msgUnity.push(_msg);
      }
    }
    _msgUnity = "{\"data\":" + JSON.stringify(_msgUnity) + "}";
    unityContext.send("ChatManager", "GetChatMessages", _msgUnity);
  };

  const getUserGroups = async () => {
    let _userGroups = await chatCoreCanister.get_user_groups();
    setUserGroups(_userGroups[0].groups);
    setTimeout(() => {
      getUserGroups();
    }, 5000);
  };

  const createGroup = async (groupName) => {
    let _group = await chatCoreCanister.create_group(groupName, true, false);
  };

  const addUserToGroup = async (json) => {
    try{
      let _data = JSON.parse(json);
      let _principal = Principal.fromText(_data.userId);
      let _addUser = await chatCoreCanister.add_user_to_group(_data.groupId, _principal);
      unityContext.send("ChatManager", "UserAdded", true);
    } catch(err){
      console.log("Unable to add user", err);
      unityContext.send("ChatManager", "UserAdded", false);
    }
  };

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
